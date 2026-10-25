separate (Files_Suite.Commands)
   procedure Test_Registered_Command_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      for Id in Files.Commands.Registered_Command_Id loop
         declare
            Identifier : constant String := Files.Commands.Identifier (Id);
            Key        : constant String := Files.Commands.Name_Key (Id);
            Description_Key : constant String := Files.Commands.Description_Key (Id);
            Text       : constant String := Files.Localization.Text (Key);
            Description : constant String := Files.Localization.Text (Description_Key);
            Primary    : constant Files.Commands.Shortcut := Files.Commands.Shortcut_For (Id);
            Secondary  : constant Files.Commands.Shortcut := Files.Commands.Secondary_Shortcut_For (Id);
            Placement  : constant Files.Commands.Command_Placement := Files.Commands.Placement_For (Id);
         begin
            Assert (Identifier /= "", "registered command identifier is non-empty");
            Assert (Files.Commands.Contains (Identifier), "registered command is found by its identifier");
            Assert (Key /= "", "registered command name key is non-empty");
            Assert (Text /= Key, "command localization exists for " & Identifier);
            Assert (Description_Key /= "", "registered command description key is non-empty");
            Assert (Description /= Description_Key, "command description localization exists for " & Identifier);
            Assert (Placement /= Files.Commands.No_Placement, "registered command has placement metadata");
            Assert
              (Files.Commands.Command_Palette_Visible (Id),
               "registered command is command-palette visible");
            Assert
              (Files.Commands.Allowed_With_Settings_Pane (Id) or else not Files.Commands.Requires_Settings_Path (Id),
               "settings-path commands are allowed while settings pane is open");
            if Primary.Present then
               Assert (Primary.Key /= Guikit.Input.Key_Unknown, "present primary shortcut has a concrete key");
               Assert
                 (Files.Commands.Shortcut_Text (Primary) /= "",
                  "present primary shortcut has searchable text");
               Files_Suite.Support.Assert_Equal
                 (Files.Commands.Find_By_Shortcut (Primary.Key, Primary.Modifiers),
                  Id,
                  "present primary shortcut routes back to command");
            else
               Files_Suite.Support.Assert_Equal
                 (Primary.Key,
                  Guikit.Input.Key_Unknown,
                  "absent primary shortcut has unknown key");
               Files_Suite.Support.Assert_Equal
                 (Files.Commands.Shortcut_Text (Primary),
                  "",
                  "absent primary shortcut has no searchable text");
            end if;
            if Secondary.Present then
               Assert (Secondary.Key /= Guikit.Input.Key_Unknown, "present secondary shortcut has a concrete key");
               Assert
                 (Files.Commands.Shortcut_Text (Secondary) /= "",
                  "present secondary shortcut has searchable text");
               Files_Suite.Support.Assert_Equal
                 (Files.Commands.Find_By_Shortcut (Secondary.Key, Secondary.Modifiers),
                  Id,
                  "present secondary shortcut routes back to command");
            else
               Files_Suite.Support.Assert_Equal
                 (Secondary.Key,
                  Guikit.Input.Key_Unknown,
                  "absent secondary shortcut has unknown key");
               Files_Suite.Support.Assert_Equal
                 (Files.Commands.Shortcut_Text (Secondary),
                  "",
                  "absent secondary shortcut has no searchable text");
            end if;
            if Id /= Files.Commands.Registered_Command_Id'First then
               for Previous in Files.Commands.Registered_Command_Id'First .. Files.Commands.Command_Id'Pred (Id) loop
                  Assert
                    (Files.Commands.Identifier (Previous) /= Identifier,
                     "registered command identifier is unique");
                  declare
                     Shortcut : constant Files.Commands.Shortcut := Files.Commands.Shortcut_For (Id);
                     Secondary : constant Files.Commands.Shortcut := Files.Commands.Secondary_Shortcut_For (Id);
                     Previous_Shortcut : constant Files.Commands.Shortcut :=
                       Files.Commands.Shortcut_For (Previous);
                     Previous_Secondary : constant Files.Commands.Shortcut :=
                       Files.Commands.Secondary_Shortcut_For (Previous);
                  begin
                     Assert
                       (not Same_Shortcut (Shortcut, Secondary),
                        "registered command primary and secondary shortcuts do not collide");
                     Assert
                       (not Same_Shortcut (Shortcut, Previous_Shortcut),
                        "registered command primary shortcut is unique");
                     Assert
                       (not Same_Shortcut (Shortcut, Previous_Secondary),
                        "registered command primary shortcut does not collide with previous secondary");
                     Assert
                       (not Same_Shortcut (Secondary, Previous_Shortcut),
                        "registered command secondary shortcut does not collide with previous primary");
                     Assert
                       (not Same_Shortcut (Secondary, Previous_Secondary),
                        "registered command secondary shortcut is unique");
                  end;
               end loop;
            end if;
         end;
      end loop;
   end Test_Registered_Command_Metadata;
