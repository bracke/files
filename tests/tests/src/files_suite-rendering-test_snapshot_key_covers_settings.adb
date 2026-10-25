separate (Files_Suite.Rendering)
   --  The window reuses its last snapshot while Snapshot_Settings_Key_Of is
   --  unchanged, so a setting Build_Snapshot depends on but the key leaves out
   --  would leave stale content on screen. Each setting is changed in turn:
   --  wherever the snapshot moves, the key must move with it; and the key holds
   --  nothing the snapshot does not depend on.
   procedure Test_Snapshot_Key_Covers_Settings (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      --  Every field of Files.Settings.Settings_Model; a new field belongs here.
      type Setting_Field is
        (Extension_Filetypes, Icon_Mappings, Open_Actions, Default_View, Show_Hidden_Files,
         Show_File_Extensions, Show_Used_Space, Show_Space_Bar, Sort_Field_Value, Sort_Ascending,
         Theme, Icon_Theme_Name, Font_Pixel_Size, Window_Width, Window_Height, Info_Pane_Open,
         Favorite_Paths, Recent_Paths_Value, Labels, Use_System_Default_Opener, Column_Visible,
         Column_Widths, Column_Order, Group_By, Shortcut_Overrides);

      Model     : constant Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Items     : constant Files.File_System.Item_Vectors.Vector := Files_Suite.Support.Sample_Items;
      Item_Path : constant String := To_String (Items.First_Element.Full_Path);
      Base      : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Base_View : constant View_Snapshot := Build_Snapshot (Model, Base);
      Base_Key  : constant Files.Settings.Snapshot_Settings_Key := Files.Settings.Snapshot_Settings_Key_Of (Base);
      Moved     : Natural := 0;

      function Changed (Field : Setting_Field) return Files.Settings.Settings_Model is
         use type Files.Settings.Theme_Choice;
         use type Files.Settings.Sort_Field;
         use type Files.Types.View_Mode;
         use type Files.Types.Group_Mode;
         Result : Files.Settings.Settings_Model := Base;
      begin
         case Field is
            when Extension_Filetypes =>
               Result.Extension_Filetypes.Include ("zzq", "application/x-zzq");
            when Icon_Mappings =>
               Result.Icon_Mappings.Include ("text/plain", "zzq-icon");
            when Open_Actions =>
               Result.Open_Actions.Include
                 ("text/plain",
                  Files.Settings.Open_Action'
                    (Executable => To_Unbounded_String ("zzq"), Arguments => <>, Use_Shell => False));
            when Default_View =>
               Result.Default_View :=
                 (if Base.Default_View = Files.Types.Details then Files.Types.Small_Icons else Files.Types.Details);
            when Show_Hidden_Files =>
               Result.Show_Hidden_Files := not Base.Show_Hidden_Files;
            when Show_File_Extensions =>
               Result.Show_File_Extensions := not Base.Show_File_Extensions;
            when Show_Used_Space =>
               Result.Show_Used_Space := not Base.Show_Used_Space;
            when Show_Space_Bar =>
               Result.Show_Space_Bar := not Base.Show_Space_Bar;
            when Sort_Field_Value =>
               Result.Sort_Field_Value :=
                 (if Base.Sort_Field_Value = Files.Settings.Sort_By_Size
                  then Files.Settings.Sort_By_Name
                  else Files.Settings.Sort_By_Size);
            when Sort_Ascending =>
               Result.Sort_Ascending := not Base.Sort_Ascending;
            when Theme =>
               Result.Theme :=
                 (if Base.Theme = Files.Settings.Theme_Light then Files.Settings.Theme_Dark
                  else Files.Settings.Theme_Light);
            when Icon_Theme_Name =>
               Append (Result.Icon_Theme_Name, "-other");
            when Font_Pixel_Size =>
               Result.Font_Pixel_Size := Base.Font_Pixel_Size + 4;
            when Window_Width =>
               Result.Window_Width := Base.Window_Width + 640;
            when Window_Height =>
               Result.Window_Height := Base.Window_Height + 480;
            when Info_Pane_Open =>
               Result.Info_Pane_Open := not Base.Info_Pane_Open;
            when Favorite_Paths =>
               Result.Favorite_Paths.Append (To_Unbounded_String (Files.Model.Current_Path (Model)));
               Result.Favorite_Paths.Append (To_Unbounded_String (Item_Path));
            when Recent_Paths_Value =>
               Result.Recent_Paths_Value.Append (To_Unbounded_String (Item_Path));
            when Labels =>
               Result.Labels.Append
                 (Files.Settings.Path_Label'(Path => To_Unbounded_String (Item_Path), Label => Files.Types.Red));
            when Use_System_Default_Opener =>
               Result.Use_System_Default_Opener := not Base.Use_System_Default_Opener;
            when Column_Visible =>
               Result.Column_Visible (Files.Types.Created_Column) :=
                 not Base.Column_Visible (Files.Types.Created_Column);
            when Column_Widths =>
               Result.Column_Widths (Files.Types.Size_Column) := Base.Column_Widths (Files.Types.Size_Column) + 100;
            when Column_Order =>
               Result.Column_Order (2) := Base.Column_Order (3);
               Result.Column_Order (3) := Base.Column_Order (2);
            when Group_By =>
               Result.Group_By :=
                 (if Base.Group_By = Files.Types.Group_By_Type then Files.Types.No_Grouping
                  else Files.Types.Group_By_Type);
            when Shortcut_Overrides =>
               Result.Shortcut_Overrides.Append
                 (Files.Settings.Shortcut_Override'
                    (Command => To_Unbounded_String ("view.details"), Combo => Null_Unbounded_String));
         end case;
         return Result;
      end Changed;
   begin
      for Field in Setting_Field loop
         declare
            Settings       : constant Files.Settings.Settings_Model := Changed (Field);
            Snapshot_Moved : constant Boolean := Build_Snapshot (Model, Settings) /= Base_View;
            Key_Moved      : constant Boolean := not Files.Settings.Same_Snapshot_Settings (Settings, Base_Key);
         begin
            Assert
              (Key_Moved or else not Snapshot_Moved,
               "changing " & Field'Image & " changes the view snapshot but not its settings key,"
               & " so the window would keep showing the stale snapshot");
            Assert
              (Snapshot_Moved or else not Key_Moved,
               "the snapshot settings key holds " & Field'Image & ", which the snapshot does not depend on");
            if Snapshot_Moved then
               Moved := Moved + 1;
            end if;
         end;
      end loop;
      Assert (Moved > 0, "changing a setting moves the snapshot at all, so the check above has teeth");
   end Test_Snapshot_Key_Covers_Settings;
