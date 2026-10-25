separate (Files_Suite.Model)
   procedure Test_Root_Discovery_Environment_Profiles (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
   begin
      Reset_Root;
      declare
         Drive_Profile_Path : constant String := Join (Root, "drive-profile-root");
         Found_Drive_Profile : Boolean := False;
         --  Restores HOME, USERPROFILE, HOMEDRIVE and HOMEPATH when the block
         --  ends, on failure too.
         Environment : Files_Suite.Support.Environment_Guard;
      begin
         Files_Suite.Support.Save (Environment, "HOME");
         Files_Suite.Support.Save (Environment, "USERPROFILE");
         Files_Suite.Support.Save (Environment, "HOMEDRIVE");
         Files_Suite.Support.Save (Environment, "HOMEPATH");
         Ada.Directories.Create_Path (Drive_Profile_Path);
         Ada.Environment_Variables.Set ("HOMEDRIVE", Root);
         Ada.Environment_Variables.Set ("HOMEPATH", "/drive-profile-root");
         Entries := Files.File_System.Available_Root_Entries;
         for Root_Entry_Value of Entries loop
            if To_String (Root_Entry_Value.Path) = Ada.Directories.Full_Name (Drive_Profile_Path)
              and then Root_Entry_Value.Kind = Files.File_System.Root_User_Mount
            then
               Found_Drive_Profile := True;
            end if;
         end loop;
         Assert
           (Found_Drive_Profile,
            "available roots include HOMEDRIVE and HOMEPATH profile directory");
      end;
      declare
         Shared_Profile_Path : constant String := Join (Root, "shared-profile-root");
         Shared_Profile_Full : Unbounded_String;
         Shared_Profile_Count : Natural := 0;
         --  Restores HOME, USERPROFILE, HOMEDRIVE and HOMEPATH when the block
         --  ends, on failure too.
         Environment : Files_Suite.Support.Environment_Guard;
      begin
         Files_Suite.Support.Save (Environment, "HOME");
         Files_Suite.Support.Save (Environment, "USERPROFILE");
         Files_Suite.Support.Save (Environment, "HOMEDRIVE");
         Files_Suite.Support.Save (Environment, "HOMEPATH");
         Ada.Directories.Create_Path (Shared_Profile_Path);
         Shared_Profile_Full := To_Unbounded_String (Ada.Directories.Full_Name (Shared_Profile_Path));
         Ada.Environment_Variables.Set ("HOME", Shared_Profile_Path);
         Ada.Environment_Variables.Set ("USERPROFILE", To_String (Shared_Profile_Full));
         Entries := Files.File_System.Available_Root_Entries;
         for Root_Entry_Value of Entries loop
            if To_String (Root_Entry_Value.Path) = To_String (Shared_Profile_Full) then
               Shared_Profile_Count := Shared_Profile_Count + 1;
            end if;
         end loop;
         Files_Suite.Support.Assert_Equal
           (Shared_Profile_Count,
            1,
            "available roots collapse duplicate HOME and USERPROFILE directories");
      end;
   end Test_Root_Discovery_Environment_Profiles;
