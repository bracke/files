separate (Files.File_System)
   function Delete_Trashed_Item
     (Trashed_Path : String)
      return Mutation_Result
   is
      Removed : constant Mutation_Result := Delete_Permanently (Trashed_Path);
      Backend : constant Trash_Backend := Trash_Backend_For_Base;
      Base    : constant String := Trash_Base_Path;
   begin
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
            when others =>
               null;
         end;
      end if;

      return Removed;
   end Delete_Trashed_Item;
