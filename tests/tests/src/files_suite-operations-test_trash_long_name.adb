with Ada.Strings.Fixed;
with Ada.Strings.Wide_Wide_Fixed;
with Files.UTF8;
separate (Files_Suite.Operations)
   --  A name too long for the trash to add ".trashinfo" or a counter to is
   --  still trashed, under a shortened name, and restored under its own.
   procedure Test_Trash_Long_Name (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  244 bytes: a leaf the filesystem stores, but not with ".trashinfo"
      --  added; Cyrillic letters, so a cut could land inside a character.
      Long_Name : constant String :=
        Ada.Strings.Fixed."*" (120, 'x')
        & Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Ada.Strings.Wide_Wide_Fixed."*" (60, "ж"))
        & ".txt";
      Original  : constant String := Join (Root, Long_Name);

      procedure Check is
         Trashed : Files.Types.UString;
         Leaf    : Unbounded_String;
      begin
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Write_File (Original, "long");
         Assert (Files.File_System.Move_To_Trash (Original, Trashed).Success,
                 "a file with a 244-byte name goes to the trash");
         Assert (not Ada.Directories.Exists (Original), "it left its folder");
         Leaf := To_Unbounded_String (Ada.Directories.Simple_Name (To_String (Trashed)));
         Assert (Length (Leaf) <= 255 - 10 - 11, "it is kept under a shortened name");
         Assert (Files.Types.Starts_With (To_String (Leaf), Ada.Strings.Fixed."*" (120, 'x'))
                 and then Ada.Directories.Extension (To_String (Leaf)) = "txt",
                 "the shortened name keeps its start and extension");
         Assert (Files.UTF8.Is_Valid (To_String (Leaf)), "the cut ends a whole character");
         Assert (Files.File_System.Restore_From_Trash (To_String (Trashed)).Success,
                 "it is restored");
         Assert (Ada.Directories.Exists (Original), "under its own name");
      end Check;
   begin
      Reset_Root;
      if Hostkit.Host.Current = Hostkit.Host.Windows then
         Files_Suite.Support.Skip ("Test_Trash_Long_Name", "the name passes the Windows path limit");
         return;
      end if;
      With_Trash_Environment (Check'Access);
   end Test_Trash_Long_Name;
