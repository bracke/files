separate (Files.Operations)
function Extract_Selected
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Items     : constant Files.File_System.Item_Vectors.Vector :=
     Files.Model.Selected_Items (Model);
   Directory : constant String := Files.Model.Current_Path (Model);

   First_Created : Unbounded_String;
   Extracted_Any : Boolean := False;
   Created       : Files.Types.String_Vectors.Vector;
   Identities    : Files.Types.String_Vectors.Vector;
   Tree_Revisions : Files.Types.String_Vectors.Vector;
   Progress_Recorded : Boolean := False;
   Verified_Count : Natural := 0;

   procedure Record_Progress is
      Previous : Files.Model.Undo_Entry;
      Found : Boolean;
   begin
      if Progress_Recorded then
         Files.Model.Take_Undo (Model, Previous, Found);
      end if;
      Progress_Recorded := Try_Record_Undo
        (Model, Files.Model.Undo_Delete_Created, Created,
         Files.Types.String_Vectors.Empty_Vector, Redoable => False,
         Original_Identities => Identities,
         Original_Tree_Revisions => Tree_Revisions,
         Retain_Verified_Main => Verified_Count);
      if Progress_Recorded
        and then Natural (Files.Model.Undo_From_Paths (Model).Length) =
          Natural (Created.Length)
      then
         Verified_Count := Natural (Created.Length);
      end if;
   end Record_Progress;

   function Trimmed_Image (Value : Positive) return String is (Files.Types.Natural_Text (Value));

   --  Treat a name ending (case-insensitively) in .zip or .7z as an archive.
   function Name_Is_Archive (Name : String) return Boolean is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Name);
   begin
      return Ada.Strings.Fixed.Tail (Lower, 4) = ".zip"
        or else Ada.Strings.Fixed.Tail (Lower, 3) = ".7z";
   end Name_Is_Archive;

   function Failed return Operation_Result is
   begin
      --  An earlier archive in the same batch may already have committed.
      --  Keep that output visible as well as undoable, while preserving the
      --  diagnostic which explains why the remaining batch stopped.
      if Created.Is_Empty then
         Files.Model.Set_Error (Model, "error.extract.failed");
      else
         declare
            Reload : constant Operation_Result :=
              Reload_With_Error (Model, Settings, "error.extract.failed");
            pragma Unreferenced (Reload);
         begin
            null;
         end;
      end if;
      return Make_Result (Operation_Failed, "error.extract.failed", Directory);
   exception
      when others =>
         Files.Model.Set_Error (Model, "error.extract.failed");
         return Make_Result (Operation_Failed, "error.extract.failed", Directory);
   end Failed;
begin
   if Files.Model.Selection_Includes_Temporary (Model) then
      return Disabled (Model, "error.create.pending");
   elsif Is_Trash_Directory (Directory) then
      return Disabled (Model, "error.extract.failed");
   elsif Files.Model.Background_Transfers (Model) then
      return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Extract);
   end if;
   if Items.Is_Empty then
      return Failed;
   end if;

   for Item of Items loop
      exit when Files.Job_Context.Cancelled;
      declare
         Item_Name : constant String := To_String (Item.Name);
         Full_Path : constant String := To_String (Item.Full_Path);
         Destination : constant String :=
           (if Files.Model.In_Recent_View (Model) or else Files.Model.Search_Results_Are_Active (Model)
            then Ada.Directories.Containing_Directory (Full_Path)
            else Directory);
      begin
         if Destination = "" then
            return Failed;
         end if;
         if Name_Is_Archive (Item_Name) then
            declare
               Raw_Base : constant String := Ada.Directories.Base_Name (Item_Name);
               Base     : constant String := (if Raw_Base = "" then "archive" else Raw_Base);

               --  A directory-unique destination folder name, e.g. "report"
               --  or "report (1)" when the first choice already exists.
               function Unique_Name return String is
               begin
                  if not Exists_Safely (Ada.Directories.Compose (Destination, Base)) then
                     return Base;
                  end if;

                  for N in 1 .. 9_999 loop
                     declare
                        Candidate : constant String := Base & " (" & Trimmed_Image (N) & ")";
                     begin
                        if not Exists_Safely (Ada.Directories.Compose (Destination, Candidate)) then
                           return Candidate;
                        end if;
                     end;
                  end loop;

                  return Base;
               end Unique_Name;

               Dest_Name : constant String := Unique_Name;
               Dest_Dir  : constant String := Ada.Directories.Compose (Destination, Dest_Name);
               Status    : Zlib.Status_Code;
               Stage     : constant String := Files.Job_Context.Create_Stage (Destination);
               Payload   : constant String := Hostkit.Fs.Join (Stage, "payload");

               procedure Discard_Stage is
                  Removed : constant Boolean := Files.Job_Context.Discard_Stage (Stage);
                  pragma Unreferenced (Removed);
               begin
                  null;
               end Discard_Stage;
            begin
               declare
                  Catalog_Status : Zlib.Status_Code;
                  Entries : constant Zlib.Archive_Entry_Array :=
                    Zlib.List_Archive_File_Entries
                      (Full_Path, "", Catalog_Status);
                  Capacity : constant Hostkit.Metadata.Volume_Capacity :=
                    Hostkit.Metadata.Volume_Capacity_Of (Destination);
               begin
                  if Catalog_Status /= Zlib.Ok
                    or else not Files.Archive_Writing.Extraction_Is_Within_Limits
                      (Entries,
                       Free_Bytes        => Capacity.Free_Bytes,
                       Free_Bytes_Known  => Capacity.Available,
                       Free_Inodes       => Capacity.Free_Inode_Count,
                       Free_Inodes_Known => Capacity.Inodes_Known,
                       Destination       => Destination)
                  then
                     return Failed;
                  end if;
               end;
               Ada.Directories.Create_Directory (Payload);
               Zlib.Extract_Archive_File_To_Directory (Full_Path, Payload, "", Status);

               declare
                  Identity : constant String := Files.File_Identities.Token (Payload);
                  Revision : constant String := Files.File_System.Tree_Revision (Payload);
               begin

                  if Status /= Zlib.Ok or else Files.Job_Context.Cancelled
                    or else Identity = "" or else Revision = ""
                    or else not Hostkit.Fs.Move_No_Replace (Payload, Dest_Dir)
                  then
                     Discard_Stage;
                     return Failed;
                  end if;

                  Files.Job_Context.Record_Created (Dest_Dir, "", Identity, Revision);
                  Identities.Append (To_Unbounded_String (Identity));
                  Tree_Revisions.Append (To_Unbounded_String (Revision));
               end;
               Discard_Stage;
               Created.Append (To_Unbounded_String (Dest_Dir));
               Record_Progress;
               if not Extracted_Any then
                  First_Created := To_Unbounded_String (Dest_Name);
                  Extracted_Any := True;
               end if;
            exception
               when others =>
                  Discard_Stage;
                  raise;
            end;
         end if;
      end;
   end loop;

   if not Extracted_Any then
      return Failed;
   end if;

   --  Reload so the new directories appear, and select the first one.
   return Reload_Current_Directory (Model, Settings, To_String (First_Created));
exception
   when others =>
      return Failed;
end Extract_Selected;
