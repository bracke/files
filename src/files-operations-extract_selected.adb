with Files.File_Types;
separate (Files.Operations)
function Extract_Selected
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Items     : constant Files.Items.Item_Vectors.Vector :=
     Files.Model.Selection.Selected_Items (Model);
   Directory : constant String := Files.Model.Current_Path (Model);

   First_Created : Unbounded_String;
   Extracted_Any : Boolean := False;
   --  The extracted folders (From).
   Progress      : Progressive_Undo :=
     (Kind => Files.Undo_History.Undo_Delete_Created, Redoable => False, others => <>);

   --  An earlier archive in the same batch may already have committed.
   --  Keep that output visible as well as undoable, while preserving the
   --  diagnostic which explains why the remaining batch stopped.
   --  An entry it cannot extract, named in the message.
   Refused_Key : constant String := "error.extract.entry_refused";

   function Failed (Key : String := "error.extract.failed") return Operation_Result is
   begin
      Finish_Failed_Undo (Model, Progress);
      return Batch_Failed (Model, Settings, Key, Directory, Wrote_Some => not Progress.Items.Is_Empty);
   end Failed;

   --  The message for an archive zlib would not read or extract: what the
   --  user can act on (a password, a damaged or unsupported archive), else
   --  the general one. The status itself is traced with the archive.
   function Failed (Archive : String; Status : Zlib.Status_Code) return Operation_Result is
   begin
      Files.Diagnostics.Trace ("Files.Operations", "extract_status=" & Status'Image & ",archive=" & Archive);
      return Failed
        (case Status is
            when Zlib.Password_Required | Zlib.Invalid_Password => "error.extract.encrypted",
            when Zlib.Unsupported_Method | Zlib.Unsupported_Preset_Dictionary => "error.extract.unsupported",
            when Zlib.Invalid_Header | Zlib.Invalid_Checksum | Zlib.Invalid_Block_Type | Zlib.Invalid_Stored_Block
               | Zlib.Invalid_Huffman_Code | Zlib.Invalid_Distance | Zlib.Unexpected_End_Of_Input =>
               "error.extract.damaged",
            when Zlib.Ok | Zlib.Input_File_Error | Zlib.Output_File_Error | Zlib.Insufficient_Memory
               | Zlib.Cancelled =>
               "error.extract.failed");
   end Failed;

   --  Extract one selected item beside it, if it is an archive: into a stage
   --  first, then published as a directory-unique folder named after it,
   --  recorded for Undo. Stop is True when the batch ends here, with Result
   --  its outcome: an entry that cannot be extracted (named in the message),
   --  limits the volume cannot hold, or a failed extraction or publish.
   procedure Extract_One
     (Item   : Files.Items.Directory_Item;
      Stop   : out Boolean;
      Result : out Operation_Result)
   is
      Item_Name : constant String := To_String (Item.Name);
      Full_Path : constant String := To_String (Item.Full_Path);
      --  Beside the archive, wherever the listing came from (a search
      --  or Recent lists items from other folders).
      Destination : constant String := Files.Fs_Primitives.Parent_Directory (Full_Path);
   begin
      Stop := False;
      if Destination = "" then
         Stop := True;
         Result := Failed;
         return;
      end if;
      if not Files.File_Types.Is_Extractable_Archive (Item_Name) then
         return;
      end if;
      declare
         Raw_Base : constant String := Files.Types.Stem_Of (Item_Name);
         Base     : constant String := (if Raw_Base = "" then "archive" else Raw_Base);

         --  A directory-unique destination folder name, e.g. "report"
         --  or "report (1)" when the first choice already exists.
         --  The bare name first, then "name (1)", "name (2)" and so on.
         function Unique_Name return String is
           (First_Free_Leaf (Destination, Base, "", Files.Leaf_Names.Numbered_Marker'Access, First => 0));

         Dest_Name : constant String := Unique_Name;
         Dest_Dir  : constant String := Hostkit.Fs.Join (Destination, Dest_Name);
         Status    : Zlib.Status_Code;
         Stage     : constant String := Files.Job_Context.Create_Stage (Destination);
         Payload   : constant String := Hostkit.Fs.Join (Stage, "payload");
         --  What identifies the published folder, for its Undo.
         Made_Identity, Made_Revision : Unbounded_String;
      begin
         declare
            Catalog_Status : Zlib.Status_Code;
            Entries : constant Zlib.Archive_Entry_Array :=
              Zlib.List_Archive_File_Entries
                (Full_Path, "", Catalog_Status);
            Capacity : constant Hostkit.Metadata.Volume_Capacity :=
              Hostkit.Metadata.Volume_Capacity_Of (Destination);
         begin
            --  A name it cannot extract is named: which entry, not
            --  only that the archive failed.
            if Catalog_Status = Zlib.Ok then
               declare
                  Refused : constant String :=
                    Files.Archive_Writing.First_Unextractable_At (Entries, Destination);
               begin
                  if Refused /= "" then
                     Discard_Stage (Stage);
                     Finish_Failed_Undo (Model, Progress);
                     --  Archives extracted before this one are shown.
                     if Progress.Items.Is_Empty then
                        Files.Model.Set_Error (Model, Refused_Key, Refused);
                     else
                        Reload_With_Error (Model, Settings, Refused_Key, Refused);
                     end if;
                     Stop := True;
                     Result := Make_Result (Operation_Failed, Refused_Key, Directory);
                     return;
                  end if;
               end;
            end if;
            if Catalog_Status /= Zlib.Ok then
               Discard_Stage (Stage);
               Stop := True;
               Result := Failed (Full_Path, Catalog_Status);
               return;
            elsif not Files.Archive_Writing.Extraction_Is_Within_Limits
                (Entries,
                 Free_Bytes        => Capacity.Free_Bytes,
                 Free_Bytes_Known  => Capacity.Available,
                 Free_Inodes       => Capacity.Free_Inode_Count,
                 Free_Inodes_Known => Capacity.Inodes_Known,
                 Destination       => Destination)
            then
               --  The stage was made before the archive was read.
               Discard_Stage (Stage);
               Stop := True;
               Result := Failed;
               return;
            end if;
         end;
         Files.Fs_Primitives.Create_Directory (Payload);
         --  The job's cancel is asked between members and while one streams,
         --  so a cancel stops a long extraction rather than waiting it out.
         Zlib.Extract_Archive_File_To_Directory
           (Full_Path, Payload, "", Cancel => Files.Job_Context.Cancelled'Access, Status => Status);

         if Status /= Zlib.Ok then
            Discard_Stage (Stage);
            Stop := True;
            Result := Failed (Full_Path, Status);
            return;
         elsif Files.Job_Context.Cancelled
           or else not Publish_Staged (Payload, Dest_Dir, Made_Identity, Made_Revision)
         then
            Discard_Stage (Stage);
            Stop := True;
            Result := Failed;
            return;
         end if;
         Discard_Stage (Stage);
         Progress.Items.Append
           (Files.Undo_History.Recorded_Item'
              (Item       =>
                 (From          => To_Unbounded_String (Dest_Dir),
                  Identity      => Made_Identity,
                  Tree_Revision => Made_Revision,
                  others        => <>),
               Provenance => Files.Undo_History.Published));
         Checkpoint_Undo (Model, Progress);
         if not Extracted_Any then
            First_Created := To_Unbounded_String (Dest_Name);
            Extracted_Any := True;
         end if;
      exception
         when others =>
            Discard_Stage (Stage);
            raise;
      end;
   end Extract_One;
begin
   declare
      Refusal : constant Operation_Result := Creation_Refusal (Model, "error.extract.failed");
   begin
      if Refusal.Status /= Operation_Success then
         return Refusal;
      end if;
   end;
   if Items.Is_Empty then
      return Failed;
   end if;

   for Item of Items loop
      exit when Files.Job_Context.Cancelled;
      declare
         Stop   : Boolean;
         Result : Operation_Result;
      begin
         Extract_One (Item, Stop, Result);
         if Stop then
            return Result;
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
