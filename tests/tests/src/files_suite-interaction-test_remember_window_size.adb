with Ada.Directories;
with Files.Preference_Types;
with Files.Settings.Path_References.Testing;
with Files.Settings.Storage;
with Files.Settings.Testing;
with Files_Suite.Support.Disk;
separate (Files_Suite.Interaction)
   --  The window size is stored through the one settings decision: the
   --  stored size writes nothing, a new one is written and loads again, and
   --  one the file cannot hold is refused with the settings as they were.
   procedure Test_Remember_Window_Size (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path     : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "size.conf");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Disk.Reset_Root;
      Files.Model.Initialize (Model, "/", Files.Items.Item_Vectors.Empty_Vector, "/");
      Settings.Window_Width := 800;
      Settings.Window_Height := 600;
      Files.Controller.Remember_Window_Size (Model, Settings, Path, 800, 600);
      Assert (not Ada.Directories.Exists (Path), "the stored size writes nothing");

      Files.Controller.Remember_Window_Size (Model, Settings, Path, 810, 620);
      Assert (Ada.Directories.Exists (Path), "a new size is written");
      declare
         Loaded : constant Files.Settings.Settings_Parse_Result := Files.Settings.Storage.Load_File (Path);
      begin
         Assert (Loaded.Success, "the written file loads");
         Files_Suite.Support.Assert_Equal
           (Loaded.Settings.Window_Width, Settings.Window_Width, "the width loads again");
         Files_Suite.Support.Assert_Equal
           (Loaded.Settings.Window_Height, Settings.Window_Height, "the height loads again");
         Files_Suite.Support.Assert_Equal (Settings.Window_Width, 810, "the live settings hold the new width");
      end;

      --  Full: a default size is not written, so a new one costs entries.
      declare
         Full  : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Index : Natural := 3_500;
      begin
         for Item in 1 .. Index loop
            Files.Settings.Path_References.Testing.Set_Label (Full, "/d/f" & Item'Image, Files.Preference_Types.Gray);
         end loop;
         loop
            Index := Index + 1;
            Files.Settings.Path_References.Testing.Set_Label (Full, "/d/f" & Index'Image, Files.Preference_Types.Gray);
            exit when not Files.Settings.Testing.Loadable (Full);
         end loop;
         Files.Settings.Path_References.Testing.Set_Label
           (Full, "/d/f" & Index'Image, Files.Preference_Types.No_Label);
         Assert (Files.Settings.Testing.Loadable (Full), "the settings are full but load");
         Files.Controller.Remember_Window_Size (Model, Full, "", 810, 620);
         Files_Suite.Support.Assert_Equal
           (Full.Window_Width, Files.Settings.Default_Settings.Window_Width, "a size the file cannot hold is refused");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model), "error.settings.full", "the error line says why");
      end;
   end Test_Remember_Window_Size;
