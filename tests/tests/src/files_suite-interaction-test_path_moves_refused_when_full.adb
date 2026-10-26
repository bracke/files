separate (Files_Suite.Interaction)
   --  Labels following a move that would make the settings file too big to
   --  load are refused whole, like any settings change: the labels stay, the
   --  error line says why, and later saves are not blocked.
   procedure Test_Path_Moves_Refused_When_Full (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Longer   : constant String := "/" & [1 .. 400 => 'x'];
      Followed : Boolean;
   begin
      for Index in 1 .. 3_000 loop
         Files.Settings.Set_Label (Settings, "/d/f" & Index'Image, Files.Types.Gray);
      end loop;
      Assert (Files.Settings.Loadable (Settings), "3000 labels fit");
      Files.Model.Initialize (Model, "/", Files.File_System.Item_Vectors.Empty_Vector, "/");
      Files.Model.Note_Path_Move (Model, "/d", Longer);
      Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
      Assert (not Followed, "a move the settings file cannot hold is not followed");
      Assert (Files.Settings.Label_Of (Settings, "/d/f" & Integer'(1)'Image) = Files.Types.Gray,
              "the labels stay where they were");
      Assert (Files.Settings.Loadable (Settings), "the settings still load");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model), "error.settings.full", "the error line says why");
   end Test_Path_Moves_Refused_When_Full;
