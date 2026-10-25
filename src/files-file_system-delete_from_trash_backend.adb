separate (Files.File_System)
function Delete_From_Trash_Backend
  (Trashed_Path : String)
   return Mutation_Result
is
   Removed : Mutation_Result;
   Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   Base    : constant String := Trash_Base_Path;
begin
   if Backend not in Trash_Xdg_Data_Home | Trash_Home_Data | Trash_Macos_Home
     or else not Is_Trash_Payload (Trashed_Path, Trash_Files_Directory)
   then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.trash.failed"));
   end if;
   Removed := Delete_Permanently (Trashed_Path);
   if not Removed.Success then
      return Removed;
   end if;

   --  Freedesktop backends keep a <base>/info/<name>.trashinfo sidecar next
   --  to the payload; remove it so the emptied entry leaves no orphaned
   --  metadata. Sidecar removal is best-effort and never fails the purge.
   if Base /= "" and then Backend in Trash_Xdg_Data_Home | Trash_Home_Data then
      declare
         Simple    : constant String := Ada.Directories.Simple_Name (Trashed_Path);
         Info_Path : constant String :=
           Join_Path (Join_Path (Base, "info"), Simple & ".trashinfo");
      begin
         if Ada.Directories.Exists (Info_Path) then
            Ada.Directories.Delete_File (Info_Path);
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System.Trash");
      end;
   end if;

   return Removed;
end Delete_From_Trash_Backend;
