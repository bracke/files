with Hostkit.Process;

separate (Files.File_System)
function Volume_Trash_Bases return Files.Types.String_Vectors.Vector is
   Result : Files.Types.String_Vectors.Vector;
   Uid    : Natural;

   procedure Consider (Base : String) is
   begin
      if not Result.Contains (To_Unbounded_String (Base))
        and then Valid_Volume_Trash_Base (Base)
        and then not Hostkit.Fs.Is_Link (Join_Path (Base, "files"))
        and then Files.Fs_Primitives.Directory_Exists (Join_Path (Base, "files"))
      then
         Result.Append (To_Unbounded_String (Base));
      end if;
   end Consider;
begin
   if not Volume_Trash_Supported or else not Hostkit.Process.Current_User_Id (Uid) then
      return Result;
   end if;
   --  Under the test suite (FILES_TEST_VOLUME_TRASH set) the mounts are not
   --  scanned, so Empty Trash in a test can only reach trashes the tests made,
   --  never a real drive's.
   for Root of Available_Root_Entries loop
      exit when Ada.Environment_Variables.Exists ("FILES_TEST_VOLUME_TRASH");
      if Root.Kind in Root_Mount | Root_User_Mount then
         declare
            Top : constant String := To_String (Root.Path);
            Id  : constant String := Natural_Text (Uid);
         begin
            Consider (Join_Path (Join_Path (Top, ".Trash"), Id));
            Consider (Join_Path (Top, ".Trash-" & Id));
         end;
      end if;
   end loop;
   for Base of Remembered_Volume_Trashes loop
      Consider (To_String (Base));
   end loop;
   return Result;
exception
   when others => return Result;
end Volume_Trash_Bases;
