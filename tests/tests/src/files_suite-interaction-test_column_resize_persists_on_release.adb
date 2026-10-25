separate (Files_Suite.Interaction)
   procedure Test_Column_Resize_Persists_On_Release (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path     : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "column-resize.conf");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Result   : Files.Interaction.Interaction_Result;
      Changed  : Boolean := False;
      Origin_X : constant := 600;
      Origin_W : constant := 120;
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
      Files.Model.Initialize
        (Model, Files_Suite.Support.Root, Files.File_System.Item_Vectors.Empty_Vector, Files_Suite.Support.Root,
         Default_View_Mode => Files.Types.Details);

      --  Several pointer moves of one drag change the width in memory only.
      for Step in 1 .. 5 loop
         Files.Interaction.Apply_Column_Resize
           (Settings, Files.Types.Size_Column,
            Origin_X     => Origin_X,
            Origin_Width => Origin_W,
            Current_X    => Origin_X - 10 * Step,
            Result       => Result);
         Changed := Changed or else Result.Settings_Changed;
         Assert (not Ada.Directories.Exists (Path), "a resize move does not write the settings file");
      end loop;
      Assert (Changed, "the drag's moves report a width change");
      Files_Suite.Support.Assert_Equal
        (Settings.Column_Widths (Files.Types.Size_Column),
         Origin_W + 50,
         "the last move's width is live in memory");

      --  Releasing the button writes the final width once.
      Files.Interaction.End_Column_Resize (Model, Settings, Path, Changed);
      Assert (Ada.Directories.Exists (Path), "the drag's end writes the settings file");
      declare
         Reloaded : constant Files.Settings.Settings_Parse_Result := Files.Settings.Load_File (Path);
      begin
         Assert (Reloaded.Success, "the persisted settings file reloads cleanly");
         Files_Suite.Support.Assert_Equal
           (Reloaded.Settings.Column_Widths (Files.Types.Size_Column),
            Origin_W + 50,
            "the settings file holds the drag's final width");
      end;
      Ada.Directories.Delete_File (Path);

      --  A drag that never changed a width writes nothing.
      Files.Interaction.End_Column_Resize (Model, Settings, Path, Changed => False);
      Assert (not Ada.Directories.Exists (Path), "a drag without a width change writes nothing");
   end Test_Column_Resize_Persists_On_Release;
