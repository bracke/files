separate (Files.Operations)
function Compress_Selected
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model;
   Format   : Archive_Format)
   return Operation_Result
is
   Items     : constant Files.File_System.Item_Vectors.Vector :=
     Files.Model.Selected_Items (Model);
   Directory : constant String :=
     (if Files.Model.In_Recent_View (Model) and then not Items.Is_Empty
      then Ada.Directories.Containing_Directory (To_String (Items.First_Element.Full_Path))
      else Files.Model.Current_Path (Model));

   Input_Paths : Files.Types.String_Vectors.Vector;
   Entry_Names : Files.Types.String_Vectors.Vector;
   Names_Seen  : Archive_Name_Sets.Set;
   Collection_Failed : Boolean := False;
   Links_Skipped     : Natural := 0;
   Max_Archive_Entries : constant Natural :=
     (if Format = Zip_Archive then 65_535 else 100_000);
   Max_Archive_Depth : constant Natural := 64;
   Max_Archive_Path_Bytes : constant Natural := 64 * 1024 * 1024;
   Collected_Path_Bytes : Natural := 0;

   function Record_Entry (Full, Entry_Name : String) return Boolean is
   begin
      if Names_Seen.Contains (Entry_Name)
        or else Full'Length > Max_Archive_Path_Bytes - Collected_Path_Bytes
        or else Entry_Name'Length >
          Max_Archive_Path_Bytes - Collected_Path_Bytes - Full'Length
      then
         return False;
      end if;
      Collected_Path_Bytes :=
        Collected_Path_Bytes + Full'Length + Entry_Name'Length;
      Names_Seen.Insert (Entry_Name);
      Input_Paths.Append (To_Unbounded_String (Full));
      Entry_Names.Append (To_Unbounded_String (Entry_Name));
      return True;
   end Record_Entry;

   --  Recursively collect directories and ordinary files, recording
   --  each with a directory-relative archive entry name (forward slashes).
   procedure Collect
     (Full       : String;
      Entry_Name : String;
      Depth      : Natural := 0)
   is
      Search    : Ada.Directories.Search_Type;
      Started   : Boolean := False;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
   begin
      if Files.Job_Context.Cancelled then
         return;
      elsif Depth > Max_Archive_Depth
        or else Natural (Input_Paths.Length) >= Max_Archive_Entries
      then
         Collection_Failed := True;
         return;
      elsif not Exists_Safely (Full) then
         Collection_Failed := True;
         return;
      elsif Hostkit.Fs.Is_Link (Full) then
         --  Skip symlinks instead of following them: Ada.Directories.Kind
         --  dereferences a link, so a link to an ancestor would recurse
         --  unbounded (Storage_Error) and a link to a directory would archive
         --  the target's contents under the link's name. The archive
         --  writers cannot store a link, so say it was left out.
         Links_Skipped := Links_Skipped + 1;
         return;
      elsif Ada.Directories.Kind (Full) = Ada.Directories.Directory then
         if not Record_Entry (Full, Entry_Name) then
            Collection_Failed := True;
            return;
         end if;
         Ada.Directories.Start_Search
           (Search,
            Directory => Full,
            Pattern   => "*",
            Filter    =>
              [Ada.Directories.Ordinary_File => True,
               Ada.Directories.Directory     => True,
               Ada.Directories.Special_File  => False]);
         Started := True;
         while not Collection_Failed
           and then not Files.Job_Context.Cancelled
           and then Ada.Directories.More_Entries (Search)
         loop
            Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
            declare
               Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            begin
               if Name /= "." and then Name /= ".." then
                  Collect
                    (Ada.Directories.Full_Name (Dir_Entry),
                     Entry_Name & "/" & Name,
                     Depth + 1);
               end if;
            end;
         end loop;
         Ada.Directories.End_Search (Search);
      elsif Ada.Directories.Kind (Full) = Ada.Directories.Ordinary_File then
         if not Record_Entry (Full, Entry_Name) then
            Collection_Failed := True;
         end if;
      end if;
   exception
      when others =>
         Collection_Failed := True;
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
   end Collect;

   function Trimmed_Image (Value : Positive) return String is
      Image : constant String := Positive'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Trimmed_Image;

   function Failed return Operation_Result is
   begin
      Files.Model.Set_Error (Model, "error.compress.failed");
      return Make_Result (Operation_Failed, "error.compress.failed", Directory);
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.compress.failed", Directory);
   end Failed;
begin
   if Files.Model.Selection_Includes_Temporary (Model) then
      return Disabled (Model, "error.create.pending");
   elsif Is_Trash_Directory (Files.Model.Current_Path (Model)) then
      return Disabled (Model, "error.compress.failed");
   elsif Files.Model.Background_Transfers (Model) then
      return Files.Operation_Jobs.Start
        (Model, Settings, (if Format = Zip_Archive then Files.Operation_Jobs.Compress_Zip
         else Files.Operation_Jobs.Compress_Seven_Zip));
   end if;
   if Items.Is_Empty or else Directory = "" then
      return Failed;
   end if;

   for Item of Items loop
      Collect (To_String (Item.Full_Path), To_String (Item.Name));
   end loop;

   if Collection_Failed or else Input_Paths.Is_Empty then
      return Failed;
   end if;
   --  Both writers refuse such names; say why rather than failing the
   --  archive with the generic error.
   for Name of Entry_Names loop
      if not Files.Archive_Writing.Portable_Entry_Name (To_String (Name)) then
         Files.Model.Set_Error (Model, "error.compress.unportable_name");
         return Make_Result (Operation_Failed, "error.compress.unportable_name", Directory);
      end if;
   end loop;

   declare
      Extension : constant String :=
        (case Format is
            when Zip_Archive       => "zip",
            when Seven_Zip_Archive => "7z");
      Raw_Base : constant String :=
        Ada.Directories.Base_Name (To_String (Items.First_Element.Name));
      Base     : constant String := (if Raw_Base = "" then "archive" else Raw_Base);

      --  A directory-unique simple archive name, e.g. "report.zip" or
      --  "report (1).zip" when the first choice already exists.
      function Unique_Name return String is
      begin
         if not Exists_Safely
                  (Ada.Directories.Compose (Directory, Base, Extension))
         then
            return Base & "." & Extension;
         end if;

         for N in 1 .. 9_999 loop
            declare
               Candidate : constant String := Base & " (" & Trimmed_Image (N) & ")";
            begin
               if not Exists_Safely
                        (Ada.Directories.Compose (Directory, Candidate, Extension))
               then
                  return Candidate & "." & Extension;
               end if;
            end;
         end loop;

         return Base & "." & Extension;
      end Unique_Name;

      Archive_Name : constant String := Unique_Name;
      Output_Path  : constant String := Ada.Directories.Compose (Directory, Archive_Name);
      Count        : constant Natural := Natural (Input_Paths.Length);
      Inputs       : Text_Array_Access := null;
      Names        : Text_Array_Access := null;
      Status       : Zlib.Status_Code;
      Stage        : constant String := Files.Job_Context.Create_Stage (Directory);
      Staged       : constant String := Ada.Directories.Compose (Stage, Archive_Name);
      Created      : Files.Types.String_Vectors.Vector;
      Identities   : Files.Types.String_Vectors.Vector;
      Tree_Revisions : Files.Types.String_Vectors.Vector;

      procedure Discard_Stage is
         Removed : constant Boolean := Files.Job_Context.Discard_Stage (Stage);
         pragma Unreferenced (Removed);
      begin
         null;
      end Discard_Stage;
   begin
      Inputs := new Zlib.Text_Array (1 .. Count);
      Names := new Zlib.Text_Array (1 .. Count);
      for I in 1 .. Count loop
         Inputs.all (I) := Input_Paths.Element (I);
         Names.all (I) := Entry_Names.Element (I);
      end loop;

      case Format is
         when Zip_Archive =>
            Files.Archive_Writing.ZIP_Files
              (Inputs.all, Staged, Names.all, Status);
         when Seven_Zip_Archive =>
            Zlib.Seven_Zip_Deflate_Files
              (Inputs.all, Staged, Names.all, Status => Status);
      end case;
      Free_Text_Array (Inputs);
      Free_Text_Array (Names);

      Identities.Append (To_Unbounded_String (Files.File_Identities.Token (Staged)));
      Tree_Revisions.Append
        (To_Unbounded_String (Files.File_System.Tree_Revision (Staged)));
      if Status /= Zlib.Ok or else Files.Job_Context.Cancelled
        or else Length (Identities.First_Element) = 0
        or else Length (Tree_Revisions.First_Element) = 0
        or else not Hostkit.Fs.Move_No_Replace (Staged, Output_Path)
      then
         Discard_Stage;
         return Failed;
      end if;
      Files.Job_Context.Record_Created
        (Output_Path, "", To_String (Identities.First_Element), To_String (Tree_Revisions.First_Element));
      Discard_Stage;
      Created.Append (To_Unbounded_String (Output_Path));
      Record_Undo
        (Model, Files.Model.Undo_Delete_Created, Created,
         Files.Types.String_Vectors.Empty_Vector, Redoable => False, Original_Identities => Identities,
         Original_Tree_Revisions => Tree_Revisions);

      --  Reload so the new archive appears, and select it.
      declare
         Reloaded : constant Operation_Result := Reload_Current_Directory (Model, Settings, Archive_Name);
      begin
         if Links_Skipped > 0 and then Reloaded.Status = Operation_Success then
            Files.Model.Set_Error (Model, "error.compress.links_skipped");
         end if;
         return Reloaded;
      end;
   exception
      when others =>
         Free_Text_Array (Inputs);
         Free_Text_Array (Names);
         Discard_Stage;
         raise;
   end;
exception
   when others =>
      return Failed;
end Compress_Selected;
