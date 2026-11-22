with Files.Timing;
separate (Files.File_System.Trash)
procedure Remove_Orphan_Info_Files is
   Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   --  Far longer than a trash takes from its info file to its move: an
   --  info file younger than this may be one in progress, in this process
   --  or another.
   Settled_Age : constant Duration := 600.0;

   procedure Sweep (Base : String) is
      Info_Dir  : constant String := Trash_Info_Directory (Base);
      Items_Dir : constant String := Trash_Items_Directory (Base);
      Now       : constant Ada.Calendar.Time := Ada.Calendar.Clock;

      procedure Check (Leaf : String; Stop : in out Boolean) is
         pragma Unreferenced (Stop);
         Info : constant String := Hostkit.Fs.Join (Info_Dir, Leaf);
      begin
         if Leaf'Length > Trash_Info_Suffix'Length
           and then Leaf (Leaf'Last - Trash_Info_Suffix'Length + 1 .. Leaf'Last) = Trash_Info_Suffix
           and then Files.IO.Fs_Primitives.Entry_Is_Absent
             (Hostkit.Fs.Join (Items_Dir, Leaf (Leaf'First .. Leaf'Last - Trash_Info_Suffix'Length)))
           and then Files.IO.Fs_Primitives.Kind (Info) = Ada.Directories.Ordinary_File
           and then Files.Timing.Elapsed (Now, Files.IO.Fs_Primitives.Modification_Time (Info), Settled_Age)
         then
            Files.IO.Fs_Primitives.Delete_File (Info);
            Files.Diagnostics.Trace ("Files.File_System", "orphan_trash_info_removed=" & Info);
         end if;
      exception
         when Swallowed : others =>
            --  One that cannot be judged or removed stays; the rest go on.
            Files.Diagnostics.Note (Swallowed, "Files.File_System");
      end Check;
   begin
      if Files.IO.Fs_Primitives.Directory_Exists (Info_Dir) then
         Files.IO.Fs_Primitives.For_Each_Name (Info_Dir, Check'Access);
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
   end Sweep;
begin
   if Backend not in Trash_Xdg_Data_Home | Trash_Home_Data then
      return;
   end if;
   declare
      Home : constant String := Trash_Base_Path;
   begin
      if Home /= "" then
         Sweep (Home);
      end if;
   end;
   for Base of Volume_Trash_Bases loop
      Sweep (To_String (Base));
   end loop;
end Remove_Orphan_Info_Files;
