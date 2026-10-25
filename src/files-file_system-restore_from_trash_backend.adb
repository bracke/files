separate (Files.File_System)
function Restore_From_Trash_Backend
  (Trashed_Path : String; Expected_Identity : String := ""; Expected_Original : String := "")
   return Mutation_Result
is
   Backend   : constant Trash_Backend := Trash_Backend_For_Base;
   Base      : constant String := Trash_Base_Path;
begin
   if Base = ""
     or else Backend not in Trash_Xdg_Data_Home | Trash_Home_Data
     or else not Is_Trash_Payload (Trashed_Path, Trash_Files_Directory)
   then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.trash.restore_unavailable"));
   end if;

   declare
      Simple    : constant String := Ada.Directories.Simple_Name (Trashed_Path);
      Info_Path : constant String :=
        Join_Path (Join_Path (Base, "info"), Simple & ".trashinfo");
      Original  : Unbounded_String;
      Parent    : Unbounded_String;
   begin
      if Expected_Original = "" and then not Ada.Directories.Exists (Info_Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_unavailable"));
      end if;

      Original := To_Unbounded_String
        (if Expected_Original /= "" then Expected_Original else Original_Path (Trashed_Path));
      if not Valid_Original_Path (To_String (Original)) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
      end if;

      Parent := To_Unbounded_String (Ada.Directories.Containing_Directory (To_String (Original)));
      if To_String (Parent) = ""
        or else not Ada.Directories.Exists (To_String (Parent))
        or else Ada.Directories.Kind (To_String (Parent)) /= Ada.Directories.Directory
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_parent_missing"));
      end if;

      if Ada.Directories.Exists (To_String (Original)) or else Hostkit.Fs.Is_Link (To_String (Original)) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_exists"));
      end if;

      if Expected_Identity /= "" then
         if not Rename_Item (Trashed_Path, To_String (Original), Expected_Identity).Success then
            return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
         end if;
      else
         begin
            if not Support.Move_No_Replace (Trashed_Path, To_String (Original)) then
               raise Ada.Directories.Use_Error;
            end if;
         exception
            when others =>
               --  Copy on the destination filesystem before publishing the
               --  restored path. A failed copy leaves Original absent, even
               --  when cleanup of the staging directory cannot finish.
               declare
                  Stage : Unbounded_String;

                  procedure Clean_Stage is
                  begin
                     if Length (Stage) > 0 then
                        declare
                           Removed : constant Boolean :=
                             Files.Job_Context.Discard_Stage (To_String (Stage));
                           pragma Unreferenced (Removed);
                        begin
                           null;
                        end;
                     end if;
                  end Clean_Stage;
               begin
                  Stage := To_Unbounded_String
                    (Files.Job_Context.Create_Stage (To_String (Parent)));
                  --  Cancellation stops new work, but must not interrupt rollback.
                  Copy_Tree (Trashed_Path, Join_Path (To_String (Stage), "payload"),
                             Check_Job_Cancellation => False, Preserve_Ownership => True);
                  if Ada.Directories.Exists (To_String (Original))
                    or else Hostkit.Fs.Is_Link (To_String (Original))
                  then
                     raise Ada.Directories.Use_Error;
                  end if;
                  if not Support.Move_No_Replace
                    (Join_Path (To_String (Stage), "payload"), To_String (Original))
                  then
                     raise Ada.Directories.Use_Error;
                  end if;
                  Clean_Stage;
               exception
                  when others =>
                     Clean_Stage;
                     return
                       (Success   => False,
                        Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
               end;
               --  The restore itself is done (the copy succeeded); removing the
               --  now-redundant trash copy is best-effort. Reporting failure here
               --  told the user the restore failed when their file is actually
               --  back, and skipped the sidecar cleanup below, leaving a stale
               --  trash entry. At worst we now leave a rare orphaned payload.
               declare
                  Removed : constant Mutation_Result := Delete_Permanently (Trashed_Path);
                  pragma Unreferenced (Removed);
               begin
                  null;
               end;
         end;
      end if;

      begin
         if Ada.Directories.Exists (Info_Path) then
            Ada.Directories.Delete_File (Info_Path);
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System.Trash");
      end;

      return (Success => True, Error_Key => Null_Unbounded_String);
   end;
exception
   when others =>
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
end Restore_From_Trash_Backend;
