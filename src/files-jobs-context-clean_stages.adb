separate (Files.Jobs.Context)
procedure Clean_Stages
  (Directory          : String;
   Owner              : Files.Jobs.Transports.Lease;
   Discard_Unreadable : Boolean := False)
is
   Stages : constant String := Hostkit.Fs.Join (Directory, Files.Protocol_Names.Stages_Directory);
   Records : Files.Types.String_Vectors.Vector;

   --  The stage folders, a link to one included, as the search listed them.
   procedure Collect (Name : String; Stop : in out Boolean) is
      pragma Unreferenced (Stop);
      Prefix : constant String := "stage-";
   begin
      if Files.Text_Basics.Starts_With (Name, Prefix)
        and then Files.IO.Fs_Primitives.Directory_Exists (Hostkit.Fs.Join (Stages, Name))
      then
         Records.Append (To_Unbounded_String (Hostkit.Fs.Join (Stages, Name)));
      end if;
   end Collect;

   procedure Clean_Record (Record_Directory : String) is
      Path, Expected : Files.Types.UString;
      Reading        : Record_Reading;
   begin
      if Hostkit.Fs.Is_Link (Record_Directory)
        or else not Files.IO.Fs_Primitives.Directory_Exists (Record_Directory)
      then
         return;
      end if;
      Read_Stage_Record (Record_Directory, Discard_Unreadable, Path, Expected, Reading);
      case Reading is
         when Record_Kept =>
            return;
         when Record_Discarded =>
            Remove_Record (Record_Directory);
            return;
         when Record_Read =>
            null;
      end case;
      if not Valid_Record_Path (To_String (Path))
        or else not Nul_Free (To_String (Expected))
        or else Files.IO.Fs_Primitives.Entry_Is_Absent (To_String (Path))
      then
         Remove_Record (Record_Directory);
         return;
      end if;
      if Length (Expected) = 0 then
         --  The write-ahead record may precede finalization.
         Expected := To_Unbounded_String (Owner_Identity (To_String (Path), Directory));
      end if;
      if Is_Own_Stage (To_String (Path), To_String (Expected), Directory)
        and then Files.Jobs.Storage.Delete_Staging_Entry (To_String (Path), To_String (Expected))
      then
         Remove_Record (Record_Directory);
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
         --  Keep only this record for retry; damage cannot hide later
         --  independent records as it could in the append-only journal.
   end Clean_Record;
begin
   if not Files.Jobs.Transports.Holds (Owner, Directory) then
      return;
   end if;
   if Hostkit.Fs.Is_Link (Stages) or else not Files.IO.Fs_Primitives.Directory_Exists (Stages) then
      return;
   end if;
   Files.IO.Fs_Primitives.For_Each_Name (Stages, Collect'Access);
   for Record_Directory of Records loop
      Clean_Record (To_String (Record_Directory));
   end loop;
   begin
      Files.IO.Fs_Primitives.Delete_Directory (Stages);
   exception
      when Ada.Directories.Use_Error => null;
   end;
exception
   when Failure : others =>
      Files.Diagnostics.Note (Failure, "Files.Jobs.Context");
end Clean_Stages;
