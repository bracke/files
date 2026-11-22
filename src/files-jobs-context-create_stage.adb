separate (Files.Jobs.Context)
function Create_Stage (Parent : String) return String is
   Record_Directory : Files.Types.UString;

   --  The stage record names each candidate before it is made, so a crash
   --  leaves an unfinished record, never an undiscoverable stage.
   procedure Publish (Path : String) is
   begin
      Record_Directory := To_Unbounded_String (Begin_Stage_Record (Path));
   end Publish;

   --  A taken name's record goes before the next is tried.
   procedure Withdraw (Path : String) is
      pragma Unreferenced (Path);
   begin
      Remove_Record (To_String (Record_Directory));
   end Withdraw;
begin
   if not Valid_Record_Path (Parent) then
      raise Ada.Directories.Use_Error;
   end if;
   declare
      Candidate : constant String :=
        Files.IO.Private_Directories.Create_Numbered
          (Parent, Files.Protocol_Names.Work_Stage_Prefix,
           Prepare => Publish'Access, Abandon => Withdraw'Access);
      Identity : Files.Types.UString;
   begin
      if Candidate = "" then
         raise Ada.Directories.Use_Error;
      end if;
      begin
         Identity := To_Unbounded_String (Files.File_Identities.Token (Candidate));
         if Length (Identity) = 0 then
            raise Ada.Directories.Use_Error;
         end if;
      exception
         when others =>
            begin
               Files.IO.Fs_Primitives.Delete_Directory (Candidate);
               Remove_Record (To_String (Record_Directory));
            exception
               when Swallowed : others =>
                  Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
            end;
            raise;
      end;
      begin
         Register_Stage_Internal
           (Candidate, To_String (Identity), To_String (Record_Directory));
      exception
         when others =>
            declare
               Removed : constant Boolean :=
                 Files.Jobs.Storage.Delete_Staging_Entry
                   (Candidate, To_String (Identity));
               pragma Unreferenced (Removed);
            begin
               null;
            end;
            if Files.IO.Fs_Primitives.Entry_Is_Absent (Candidate) then
               Remove_Record (To_String (Record_Directory));
            end if;
            raise;
      end;
      if Length (Current) = 0 then
         Foreground_Paths.Append (To_Unbounded_String (Candidate));
         Foreground_Records.Append (Record_Directory);
      end if;
      return Candidate;
   end;
exception
   when others =>
      if Length (Current) = 0 and then Foreground_Paths.Is_Empty
        and then Files.Jobs.Process.Active (Foreground_Job)
      then
         Files.Jobs.Process.Reset (Foreground_Job);
      end if;
      raise;
end Create_Stage;
