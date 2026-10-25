separate (Files_Suite.Settings)
   procedure Test_Detail_Columns_And_Grouping (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Group_Mode;
      Base : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      --  Defaults: name/modified/size/type visible, created/permissions hidden.
      Assert (Base.Column_Visible (Files.Types.Name_Column), "name column shown by default");
      Assert (Base.Column_Visible (Files.Types.Size_Column), "size column shown by default");
      Assert (not Base.Column_Visible (Files.Types.Permissions_Column),
              "permissions column hidden by default");
      Files_Suite.Support.Assert_Equal (Base.Group_By, Files.Types.No_Grouping, "grouping is off by default");

      --  Toggle helpers: name is never toggleable, others flip.
      declare
         Toggled : constant Files.Settings.Settings_Model :=
           Files.Settings.Toggle_Column (Base, Files.Types.Permissions_Column);
         Name_Fixed : constant Files.Settings.Settings_Model :=
           Files.Settings.Toggle_Column (Base, Files.Types.Name_Column);
      begin
         Assert (Toggled.Column_Visible (Files.Types.Permissions_Column),
                 "toggling permissions makes it visible");
         Assert (Name_Fixed.Column_Visible (Files.Types.Name_Column),
                 "toggling the name column leaves it visible");
      end;

      --  Width clamp: below the minimum is raised, zero clears the override.
      declare
         Narrow : constant Files.Settings.Settings_Model :=
           Files.Settings.With_Column_Width (Base, Files.Types.Size_Column, 5);
         Wide   : constant Files.Settings.Settings_Model :=
           Files.Settings.With_Column_Width (Base, Files.Types.Size_Column, 200);
         Reset  : constant Files.Settings.Settings_Model :=
           Files.Settings.With_Column_Width (Wide, Files.Types.Size_Column, 0);
      begin
         Files_Suite.Support.Assert_Equal
           (Narrow.Column_Widths (Files.Types.Size_Column),
            Files.Types.Minimum_Detail_Column_Width,
            "sub-minimum width is clamped up to the minimum");
         Files_Suite.Support.Assert_Equal
           (Wide.Column_Widths (Files.Types.Size_Column),
            200,
            "an explicit width is retained");
         Files_Suite.Support.Assert_Equal
           (Reset.Column_Widths (Files.Types.Size_Column),
            0,
            "a zero width clears the customization");
      end;

      --  Group cycle wraps back to No_Grouping after the last band.
      declare
         G1 : constant Files.Settings.Settings_Model := Files.Settings.Cycle_Group_By (Base);
         G2 : constant Files.Settings.Settings_Model := Files.Settings.Cycle_Group_By (G1);
         G3 : constant Files.Settings.Settings_Model := Files.Settings.Cycle_Group_By (G2);
         G4 : constant Files.Settings.Settings_Model := Files.Settings.Cycle_Group_By (G3);
         G5 : constant Files.Settings.Settings_Model := Files.Settings.Cycle_Group_By (G4);
      begin
         Files_Suite.Support.Assert_Equal (G1.Group_By, Files.Types.Group_By_Type, "first cycle selects type grouping");
         Files_Suite.Support.Assert_Equal
           (G2.Group_By,
            Files.Types.Group_By_Modified,
            "second cycle selects date grouping");
         Files_Suite.Support.Assert_Equal (G3.Group_By, Files.Types.Group_By_Size, "third cycle selects size grouping");
         Files_Suite.Support.Assert_Equal
           (G4.Group_By,
            Files.Types.Group_By_Label,
            "fourth cycle selects label grouping");
         Files_Suite.Support.Assert_Equal (G5.Group_By, Files.Types.No_Grouping, "grouping cycles back to none");
      end;

      --  Full round-trip through the settings text format.
      declare
         Source : Files.Settings.Settings_Model := Base;
      begin
         Source := Files.Settings.Toggle_Column (Source, Files.Types.Size_Column);
         Source := Files.Settings.Toggle_Column (Source, Files.Types.Created_Column);
         Source := Files.Settings.With_Column_Width (Source, Files.Types.Modified_Column, 175);
         Source := Files.Settings.Cycle_Group_By (Source);
         Source := Files.Settings.Cycle_Group_By (Source);
         declare
            Reloaded : constant Files.Settings.Settings_Parse_Result :=
              Files.Settings.Parse (Files.Settings.To_Text (Source));
         begin
            Assert (Reloaded.Success, "customized column settings text parses");
            Assert (not Reloaded.Settings.Column_Visible (Files.Types.Size_Column),
                    "hidden size column round-trips");
            Assert (Reloaded.Settings.Column_Visible (Files.Types.Created_Column),
                    "enabled created column round-trips");
            Files_Suite.Support.Assert_Equal
              (Reloaded.Settings.Column_Widths (Files.Types.Modified_Column),
               175,
               "custom modified width round-trips");
            Files_Suite.Support.Assert_Equal
              (Reloaded.Settings.Group_By,
               Files.Types.Group_By_Modified,
               "grouping mode round-trips");
         end;
      end;

      --  An invalid grouping mode is diagnosed.
      declare
         Bad : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse ("[settings]" & ASCII.LF & "group_by = weekly" & ASCII.LF);
      begin
         Assert (not Bad.Success, "an unknown grouping mode fails to parse");
         Files_Suite.Support.Assert_Equal
           (To_String (Bad.Error_Key),
            "error.settings.invalid_group",
            "the grouping diagnostic key is reported");
      end;
   end Test_Detail_Columns_And_Grouping;
