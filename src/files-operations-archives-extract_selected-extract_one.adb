with Files.Items;
separate (Files.Operations.Archives.Extract_Selected)
procedure Extract_One
  (Item   : Files.Items.Directory_Item;
   Stop   : out Boolean;
   Result : out Operation_Result)
is
   Item_Name : constant String := To_String (Item.Name);
   Full_Path : constant String := To_String (Item.Full_Path);
   --  Beside the archive, wherever the listing came from (a search
   --  or Recent lists items from other folders).
   Destination : constant String := Files.IO.Fs_Primitives.Parent_Directory (Full_Path);
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
      Raw_Base : constant String := Files.Name_Parts.Stem_Of (Item_Name);
      Base     : constant String := (if Raw_Base = "" then "archive" else Raw_Base);

      --  A directory-unique destination folder name, e.g. "report"
      --  or "report (1)" when the first choice already exists.
      --  The bare name first, then "name (1)", "name (2)" and so on.
      function Unique_Name return String is
        (First_Free_Leaf (Destination, Base, "", Files.Leaf_Names.Numbered_Marker'Access, First => 0));

      Dest_Name : constant String := Unique_Name;
      Dest_Dir  : constant String := Hostkit.Fs.Join (Destination, Dest_Name);
      Status    : Zlib.Status_Code;
      Stage     : constant String := Files.Jobs.Context.Create_Stage (Destination);
      Payload   : constant String := Hostkit.Fs.Join (Stage, Files.Protocol_Names.Stage_Payload);
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
                 Files.Operations.Archives.Writing.First_Unextractable_At (Entries, Destination);
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
         elsif not Files.Operations.Archives.Writing.Extraction_Is_Within_Limits
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
      Files.IO.Fs_Primitives.Create_Directory (Payload);
      --  The job's cancel is asked between members and while one streams,
      --  so a cancel stops a long extraction rather than waiting it out.
      Zlib.Extract_Archive_File_To_Directory
        (Full_Path, Payload, "", Cancel => Files.Jobs.Context.Cancelled'Access, Status => Status);

      if Status /= Zlib.Ok then
         Discard_Stage (Stage);
         Stop := True;
         Result := Failed (Full_Path, Status);
         return;
      elsif Files.Jobs.Context.Cancelled
        or else not Publish_Staged (Payload, Dest_Dir, Made_Identity, Made_Revision)
      then
         Discard_Stage (Stage);
         Stop := True;
         Result := Failed;
         return;
      end if;
      Discard_Stage (Stage);
      Progress.Items.Append
        (Files.Undo.History.Recorded_Item'
           (Item       =>
              (From          => To_Unbounded_String (Dest_Dir),
               Identity      => Made_Identity,
               Tree_Revision => Made_Revision,
               others        => <>),
            Provenance => Files.Undo.History.Published));
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
