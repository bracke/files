with Hostkit.Host;
with Files.File_Types;
separate (Files.Operations)
function Extract_Selected
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Items     : constant Files.Items.Item_Vectors.Vector :=
     Files.Model.Selected_Items (Model);
   Directory : constant String := Files.Model.Current_Path (Model);

   First_Created : Unbounded_String;
   Extracted_Any : Boolean := False;
   --  The extracted folders (From).
   Progress      : Progressive_Undo := (Kind => Files.Model.Undo_Delete_Created, Redoable => False, others => <>);

   --  An earlier archive in the same batch may already have committed.
   --  Keep that output visible as well as undoable, while preserving the
   --  diagnostic which explains why the remaining batch stopped.
   function Failed return Operation_Result is
   begin
      Finish_Failed_Undo (Model, Progress);
      return Batch_Failed
        (Model, Settings, "error.extract.failed", Directory, Wrote_Some => not Progress.From.Is_Empty);
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
         --  Beside the archive, wherever the listing came from (a search
         --  or Recent lists items from other folders).
         Destination : constant String := Files.Fs_Primitives.Parent_Directory (Full_Path);
      begin
         if Destination = "" then
            return Failed;
         end if;
         if Files.File_Types.Is_Extractable_Archive (Item_Name) then
            declare
               Raw_Base : constant String := Files.Types.Stem_Of (Item_Name);
               Base     : constant String := (if Raw_Base = "" then "archive" else Raw_Base);

               --  A directory-unique destination folder name, e.g. "report"
               --  or "report (1)" when the first choice already exists.
               --  The bare name first, then "name (1)", "name (2)" and so on.
               function Marker (Attempt : Natural) return String is
                 (if Attempt = 0 then "" else " (" & Files.Types.Natural_Text (Attempt) & ")");
               function Unique_Name return String is
                 (First_Free_Name (Destination, Base, "", Marker'Access, First => 0));

               Dest_Name : constant String := Unique_Name;
               Dest_Dir  : constant String := Hostkit.Fs.Join (Destination, Dest_Name);
               Status    : Zlib.Status_Code;
               Stage     : constant String := Files.Job_Context.Create_Stage (Destination);
               Payload   : constant String := Hostkit.Fs.Join (Stage, "payload");
               --  What identifies the published folder, for its Undo.
               Made_Identity, Made_Revision : Unbounded_String;

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
                     --  The stage was made before the archive was read.
                     Discard_Stage;
                     return Failed;
                  end if;
               end;
               Files.Fs_Primitives.Create_Directory (Payload);
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

                  declare
                     --  The stage handed the payload owner-only access, which
                     --  the rename kept on Windows: let the destination's
                     --  inheritance replace it, as for any folder made there.
                     --  That writes the change times the folder's revision
                     --  reads, so it is taken afresh. A failure leaves the
                     --  folder owner-only, no reason to undo the extraction.
                     Published : constant String :=
                       (if Hostkit.Metadata.Inherit_From_Parent (Dest_Dir)
                          and then Hostkit.Host."=" (Hostkit.Host.Current, Hostkit.Host.Windows)
                        then Files.File_System.Tree_Revision (Dest_Dir)
                        else Revision);
                  begin
                     Files.Job_Context.Record_Created (Dest_Dir, "", Identity, Published);
                     Made_Identity := To_Unbounded_String (Identity);
                     Made_Revision := To_Unbounded_String (Published);
                  end;
               end;
               Discard_Stage;
               Progress.From.Append (To_Unbounded_String (Dest_Dir));
               Progress.Identities.Append (Made_Identity);
               Progress.Tree_Revisions.Append (Made_Revision);
               Checkpoint_Undo (Model, Progress);
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
   declare
      Undo : constant Undo_Outcome := Finish_Undo (Model, Progress);
   begin
      if not Extracted_Any then
         return Failed;
      end if;

      --  Reload so the new directories appear, and select the first one.
      declare
         Result : constant Operation_Result := Reload_Current_Directory (Model, Settings, To_String (First_Created));
      begin
         Note_Undo_Outcome (Model, Undo, Result);
         return Result;
      end;
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      return Failed;
end Extract_Selected;
