with Files.Durability;
with Hostkit.Durability;
separate (Files.Operations)
function Compress_Selected
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model;
   Format   : Archive_Format)
   return Operation_Result
is
   Items     : constant Files.Items.Item_Vectors.Vector :=
     Files.Model.Selection.Selected_Items (Model);
   Directory : constant String :=
     (if Files.Model.In_Recent_View (Model) and then not Items.Is_Empty
      then Files.Fs_Primitives.Parent_Directory (To_String (Items.First_Element.Full_Path))
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
      procedure Visit (Name : String; Kind : Hostkit.Fs.Entry_Kind; Stop : in out Boolean) is
         use type Hostkit.Fs.Entry_Kind;
      begin
         if Collection_Failed or else Files.Job_Context.Cancelled then
            Stop := True;
         elsif Kind in Hostkit.Fs.Ordinary_File_Entry | Hostkit.Fs.Directory_Entry then
            Collect (Hostkit.Fs.Join (Full, Name), Entry_Name & "/" & Name, Depth + 1);
         end if;
      end Visit;
   begin
      if Files.Job_Context.Cancelled then
         return;
      elsif Depth > Max_Archive_Depth
        or else Natural (Input_Paths.Length) >= Max_Archive_Entries
      then
         Collection_Failed := True;
         return;
      --  refusal-safe: a refused lookup fails the collection
      elsif not Files.Fs_Primitives.Entry_Exists (Full) then
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
      elsif Files.Fs_Primitives.Kind (Full) = Ada.Directories.Directory then
         if not Record_Entry (Full, Entry_Name) then
            Collection_Failed := True;
            return;
         end if;
         Files.Fs_Primitives.For_Each_Listed (Full, Visit'Access);
      elsif Files.Fs_Primitives.Kind (Full) = Ada.Directories.Ordinary_File then
         if not Record_Entry (Full, Entry_Name) then
            Collection_Failed := True;
         end if;
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Operations");
         Collection_Failed := True;
   end Collect;

   function Failed return Operation_Result is
   begin
      Files.Model.Set_Error (Model, "error.compress.failed");
      return Make_Result (Operation_Failed, "error.compress.failed", Directory);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Operations");
         return Make_Result (Operation_Failed, "error.compress.failed", Directory);
   end Failed;
begin
   declare
      Refusal : constant Operation_Result := Creation_Refusal (Model, "error.compress.failed");
   begin
      if Refusal.Status /= Operation_Success then
         return Refusal;
      end if;
   end;
   if Items.Is_Empty or else Directory = "" then
      return Failed;
   end if;

   --  Items from a search or Recent can share a name ("readme.txt" from two
   --  folders): the later one is stored as "readme 2.txt" rather than the
   --  archive failing. Compared folded, so it also extracts on a volume
   --  that folds case.
   declare
      Top_Names : Archive_Name_Sets.Set;

      --  An archive entry's name is bounded only by the format's 16-bit
      --  name field, not by a volume.
      Entry_Limit : constant Hostkit.Fs.Leaf_Name_Limit := (Unit => Hostkit.Fs.Bytes, Most => 65_535);

      function Taken (Name : String) return Boolean is (Top_Names.Contains (Files.Types.Fold_Case (Name)));

      --  The numbering a paste gives a name in use: "readme 2.txt", a plain
      --  folder's dots kept in its name.
      function Entry_For (Name : String; Is_Folder : Boolean) return String is
         Free : constant String :=
           Files.Leaf_Names.First_Free
             (Files.Types.Name_Stem (Name, Is_Folder), Files.Types.Name_Extension (Name, Is_Folder),
              Files.Leaf_Names.Spaced_Number'Access, Taken'Access, Entry_Limit);
      begin
         return (if Free = "" then Name else Free);
      end Entry_For;
   begin
      for Item of Items loop
         declare
            Name : constant String :=
              Entry_For (To_String (Item.Name), Item.Kind = Files.Types.Directory_Item);
         begin
            Top_Names.Include (Files.Types.Fold_Case (Name));
            Collect (To_String (Item.Full_Path), Name);
         end;
      end loop;
   end;

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
      --  ".bashrc" is all name: ".bashrc.zip", not ".zip"; so is a plain
      --  folder's: "photos.2024.zip", not "photos.zip".
      Raw_Base : constant String :=
        Files.Types.Name_Stem
          (To_String (Items.First_Element.Name), Items.First_Element.Kind = Files.Types.Directory_Item);
      Base     : constant String := (if Raw_Base = "" then "archive" else Raw_Base);

      --  A directory-unique simple archive name, e.g. "report.zip" or
      --  "report (1).zip" when the first choice already exists.
      function Unique_Name return String is
        (First_Free_Leaf (Directory, Base, Extension, Files.Leaf_Names.Numbered_Marker'Access, First => 0));

      Archive_Name : constant String := Unique_Name;
      Output_Path  : constant String := Hostkit.Fs.Join (Directory, Archive_Name);
      Count        : constant Natural := Natural (Input_Paths.Length);
      Inputs       : Text_Array_Access := null;
      Names        : Text_Array_Access := null;
      Status       : Zlib.Status_Code;
      Stage        : constant String := Files.Job_Context.Create_Stage (Directory);
      Staged       : constant String := Hostkit.Fs.Join (Stage, Archive_Name);
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
      --  The archive's bytes are on the device before its name is published,
      --  as every durable copy's are: a power cut leaves no recorded but
      --  empty or cut-short archive.
      if Status /= Zlib.Ok or else Files.Job_Context.Cancelled
        or else Length (Identities.First_Element) = 0
        or else Length (Tree_Revisions.First_Element) = 0
        or else Hostkit.Durability."=" (Files.Durability.Sync_File (Staged), Hostkit.Durability.Failed)
        or else not Hostkit.Fs.Move_No_Replace (Staged, Output_Path)
      then
         Discard_Stage;
         return Failed;
      end if;
      --  The stage handed the archive owner-only access, which the rename
      --  kept on Windows: let the destination's inheritance replace it, as
      --  for any file made there. A file's revision leaves out the change
      --  time this writes; a failure leaves the archive owner-only, no
      --  reason to undo it.
      declare
         Inherited : constant Boolean := Hostkit.Metadata.Inherit_From_Parent (Output_Path);
         pragma Unreferenced (Inherited);
      begin
         null;
      end;
      Files.Job_Context.Record_Created
        (Output_Path, "", To_String (Identities.First_Element), To_String (Tree_Revisions.First_Element));
      Discard_Stage;
      Record_Undo
        (Model, Files.Model.Undo_Delete_Created,
         Published
           (Files.Model.Undo_Item_Vectors.To_Vector
              ((From          => To_Unbounded_String (Output_Path),
                Identity      => Identities.First_Element,
                Tree_Revision => Tree_Revisions.First_Element,
                others        => <>), 1)),
         Redoable => False);

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
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      return Failed;
end Compress_Selected;
