with Files.Controller.Testing;
with Ada.Directories;
with Files.Model.Recent;
with Files.Preference_Types;
with Files.Settings.Path_References;
with Files.Settings.Path_References.Testing;
with Files.Settings.Storage;
with Files.Settings.Testing;
with Files_Suite.Support.Disk;
separate (Files_Suite.Interaction)
   --  Opens and path moves the window queued go into the settings as one
   --  edit and one write; should the longer recent list make the file too
   --  big to load again, the moves still go in on their own and the error
   --  line says the settings are full.
   procedure Test_Recent_Opens_And_Moves (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Gray : constant Files.Preference_Types.Color_Label := Files.Preference_Types.Gray;

      function Recent_Has (Settings : Files.Settings.Settings_Model; Path : String) return Boolean is
      begin
         for Item of Files.Settings.Path_References.Recent_Paths (Settings) loop
            if Ada.Strings.Unbounded.To_String (Item) = Path then
               return True;
            end if;
         end loop;
         return False;
      end Recent_Has;
   begin
      Files_Suite.Support.Disk.Reset_Root;
      --  Together: one write holds both the moved label and the opened path.
      declare
         Path     : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "both.conf");
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Model    : Files.Model.Window_Model;
         Accepted : Boolean;
      begin
         Files.Settings.Path_References.Testing.Set_Label (Settings, "/d/f", Gray);
         Files.Model.Initialize (Model, "/", Files.Items.Item_Vectors.Empty_Vector, "/");
         Files.Model.Recent.Note_Path_Move (Model, "/d", "/e");
         Files.Model.Recent.Note_Recent_Open (Model, "/opened");
         Files.Controller.Testing.Note_Recent_Opens (Model, Settings, Path, Accepted);
         Assert (Accepted, "the opens and the moves are taken");
         Assert (Files.Settings.Path_References.Label_Of (Settings, "/e/f") = Gray, "the label followed the move");
         Assert (Recent_Has (Settings, "/opened"), "the open is recorded");
         declare
            Loaded : constant Files.Settings.Settings_Parse_Result := Files.Settings.Storage.Load_File (Path);
         begin
            Assert (Loaded.Success, "the written file loads");
            Assert
              (Files.Settings.Path_References.Label_Of (Loaded.Settings, "/e/f") = Gray
               and then Recent_Has (Loaded.Settings, "/opened"),
               "the file holds the moved label and the open together");
         end;
         Assert
           (Files.Model.Recent.Take_Recent_Opens (Model).Is_Empty
            and then Files.Model.Recent.Take_Path_Moves (Model).Is_Empty,
            "both queues are drained");
      end;
      --  Full: the moves cost no entry, the open one more than the file holds.
      declare
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Model    : Files.Model.Window_Model;
         Accepted : Boolean;
         Index    : Natural := 3_500;
      begin
         for Item in 1 .. Index loop
            Files.Settings.Path_References.Testing.Set_Label (Settings, "/d/f" & Item'Image, Gray);
         end loop;
         loop
            Index := Index + 1;
            Files.Settings.Path_References.Testing.Set_Label (Settings, "/d/f" & Index'Image, Gray);
            exit when not Files.Settings.Testing.Loadable (Settings);
         end loop;
         Files.Settings.Path_References.Testing.Set_Label
           (Settings, "/d/f" & Index'Image, Files.Preference_Types.No_Label);
         Assert (Files.Settings.Testing.Loadable (Settings), "the settings are full but load");
         Files.Model.Initialize (Model, "/", Files.Items.Item_Vectors.Empty_Vector, "/");
         Files.Model.Recent.Note_Path_Move (Model, "/d", "/e");
         Files.Model.Recent.Note_Recent_Open (Model, "/opened");
         Files.Controller.Testing.Note_Recent_Opens (Model, Settings, "", Accepted);
         Assert (Accepted, "the moves go in on their own");
         Assert
           (Files.Settings.Path_References.Label_Of (Settings, "/e/f 1") = Gray,
            "the labels followed the move");
         Assert (not Recent_Has (Settings, "/opened"), "the open the file cannot hold is not recorded");
         Assert (Files.Settings.Testing.Loadable (Settings), "the settings still load");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model), "error.settings.full", "the error line says why");
      end;
   end Test_Recent_Opens_And_Moves;
