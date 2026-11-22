separate (Files.Jobs.Context)
function Discard_Stage (Path : String) return Boolean is
   Directory, Identity : Files.Types.UString;
   Owner_Valid : Boolean;
   Foreground : constant Boolean := Length (Current) = 0;
   Foreground_Index : Natural := 0;
   Record_Directory : Files.Types.UString;
   Removed : Boolean := False;

   procedure Release_Foreground is
   begin
      if not Foreground or else Foreground_Index = 0 then
         return;
      end if;
      if Removed then
         Remove_Record (To_String (Record_Directory));
      end if;
      Foreground_Paths.Delete (Foreground_Index);
      Foreground_Records.Delete (Foreground_Index);
      --  A stage that is gone by other means (removed from outside) is no
      --  longer waiting for its discard: forgotten here, or the cleanup
      --  below would never run again in this process.
      for Index in reverse Foreground_Paths.First_Index .. Foreground_Paths.Last_Index loop
         if Files.IO.Fs_Primitives.Entry_Is_Absent (To_String (Foreground_Paths (Index))) then
            Remove_Record (To_String (Foreground_Records (Index)));
            Foreground_Paths.Delete (Index);
            Foreground_Records.Delete (Index);
         end if;
      end loop;
      if Foreground_Paths.Is_Empty and then Files.Jobs.Process.Active (Foreground_Job) then
         Files.Jobs.Process.Clean_Stages (Foreground_Job);
         --  Failed records remain in the transport directory. Releasing the
         --  session launches the normal cleanup helper and retains it for
         --  retry instead of abandoning a foreground stage.
         Files.Jobs.Process.Reset (Foreground_Job);
      end if;
   end Release_Foreground;
begin
   if Foreground then
      for Index in Foreground_Paths.First_Index .. Foreground_Paths.Last_Index loop
         if To_String (Foreground_Paths (Index)) = Path then
            Foreground_Index := Index;
            Record_Directory := Foreground_Records (Index);
            exit;
         end if;
      end loop;
      if Foreground_Index = 0 or else not Files.Jobs.Process.Active (Foreground_Job) then
         return False;
      end if;
   end if;
   if Files.IO.Fs_Primitives.Entry_Is_Absent (Path) then
      Removed := True;
      Release_Foreground;
      return True;
   end if;
   Read_Owner (Path, Directory, Identity, Owner_Valid);
   if Owner_Valid
     and then To_String (Directory) =
       (if Foreground then Files.Jobs.Process.Path (Foreground_Job, "") else To_String (Current))
   then
      Removed := Files.Jobs.Storage.Delete_Staging_Entry (Path, To_String (Identity));
   end if;
   Release_Foreground;
   return Removed;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
      Release_Foreground;
      return False;
end Discard_Stage;
