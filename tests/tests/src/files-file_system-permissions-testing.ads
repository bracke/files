--  Test-only access to Files.File_System.Permissions' private part: the
--  hook that watches which ownership changes are asked of the host.
package Files.File_System.Permissions.Testing is

   --  From now on, count every ownership change asked of Change_Ownership
   --  (from zero), and keep the ids the last one asked for.
   procedure Watch_Ownership_Changes;

   --  Count ownership changes no more.
   procedure Stop_Watching_Ownership_Changes;

   --  @return The ownership changes asked for since Watch_Ownership_Changes.
   function Ownership_Changes return Natural;

   --  @return The user id the last ownership change asked for.
   function Last_Ownership_User return Files.Types.Account_Id;

   --  @return The group id the last ownership change asked for.
   function Last_Ownership_Group return Files.Types.Account_Id;

end Files.File_System.Permissions.Testing;
