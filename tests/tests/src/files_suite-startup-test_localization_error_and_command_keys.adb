separate (Files_Suite.Startup)
   procedure Test_Localization_Error_And_Command_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Error_Keys : Files.Types.String_Vectors.Vector;
      Western_Locales : constant Files.Types.String_Vectors.Vector :=
        [To_Unbounded_String ("da-DK"), To_Unbounded_String ("de-DE"), To_Unbounded_String ("es-ES"),
         To_Unbounded_String ("fr-FR"), To_Unbounded_String ("it-IT"), To_Unbounded_String ("nl-NL"),
         To_Unbounded_String ("pt-PT"), To_Unbounded_String ("sv-SE"), To_Unbounded_String ("nb-NO"),
         To_Unbounded_String ("fi-FI")];

      procedure Add_Error_Key (Key : String) is
      begin
         Error_Keys.Append (To_Unbounded_String (Key));
      end Add_Error_Key;
   begin
      Add_Error_Key ("error.path.missing");
      Add_Error_Key ("error.recovery.unsafe_transport");
      Add_Error_Key ("error.path.inaccessible");
      Add_Error_Key ("error.directory.load");
      Add_Error_Key ("error.startup.too_many_windows");
      Add_Error_Key ("error.metadata.read");
      Add_Error_Key ("error.file.create");
      Add_Error_Key ("error.file.exists");
      Add_Error_Key ("error.file.parent_missing");
      Add_Error_Key ("error.rename.source_missing");
      Add_Error_Key ("error.rename.invalid_destination");
      Add_Error_Key ("error.rename.failed");
      Add_Error_Key ("error.rename.partial");
      Add_Error_Key ("error.trash.unavailable");
      Add_Error_Key ("error.trash.failed");
      Add_Error_Key ("error.trash.native_unavailable");
      Add_Error_Key ("error.trash.restore_unavailable");
      Add_Error_Key ("error.trash.restore_failed");
      Add_Error_Key ("error.trash.restore_parent_missing");
      Add_Error_Key ("error.trash.restore_exists");
      Add_Error_Key ("error.trash.empty_partial");
      Add_Error_Key ("error.trash.empty_failed");
      Add_Error_Key ("error.search.failed");
      Add_Error_Key ("search.no_matches");
      Add_Error_Key ("error.permanent_delete.refused");
      Add_Error_Key ("error.permanent_delete.failed");
      Add_Error_Key ("error.permissions.failed");
      Add_Error_Key ("error.permissions.unsupported");
      Add_Error_Key ("error.ownership.denied");
      Add_Error_Key ("error.ownership.unsupported");
      Add_Error_Key ("error.ownership.invalid_name");
      Add_Error_Key ("error.drop.invalid_destination");
      Add_Error_Key ("error.drop.invalid_source");
      Add_Error_Key ("error.drop.failed");
      Add_Error_Key ("error.move.source_changed");
      Add_Error_Key ("error.move.source_set_aside");
      Add_Error_Key ("error.settings.not_persisted");
      Add_Error_Key ("error.extract.not_archive");
      Add_Error_Key ("error.clipboard.empty");
      Add_Error_Key ("error.command.recent_view");
      Add_Error_Key ("error.command.trash_view");
      Add_Error_Key ("error.drop.into_self");
      Add_Error_Key ("error.copy.failed");
      Add_Error_Key ("error.io.no_space");
      Add_Error_Key ("error.io.denied");
      Add_Error_Key ("error.io.read_only");
      Add_Error_Key ("error.io.busy");
      Add_Error_Key ("error.io.name_too_long");
      Add_Error_Key ("error.duplicate.failed");
      Add_Error_Key ("error.link.failed");
      Add_Error_Key ("error.terminal.unavailable");
      Add_Error_Key ("error.compress.failed");
      Add_Error_Key ("error.compress.unportable_name");
      Add_Error_Key ("error.extract.failed");
      Add_Error_Key ("error.undo.failed");
      Add_Error_Key ("error.redo.failed");
      Add_Error_Key ("error.operation.failed");
      Add_Error_Key ("error.thumbnail.source_missing");
      Add_Error_Key ("error.thumbnail.unsupported");
      Add_Error_Key ("error.thumbnail.failed");
      Add_Error_Key ("error.history.back_unavailable");
      Add_Error_Key ("error.history.forward_unavailable");
      Add_Error_Key ("error.navigate.no_parent");
      Add_Error_Key ("error.selection.empty");
      Add_Error_Key ("error.create.pending");
      Add_Error_Key ("error.create.no_temporary_item");
      Add_Error_Key ("error.filter.empty");
      Add_Error_Key ("error.root.selection.empty");
      Add_Error_Key ("error.root.eject_unavailable");
      Add_Error_Key ("error.name.invalid");
      Add_Error_Key ("error.rename.disabled");
      Add_Error_Key ("error.open_action.missing");
      Add_Error_Key ("error.open_action.multi_directory");
      Add_Error_Key ("error.open_action.execution");
      Add_Error_Key ("error.open_action.executable_missing");
      Add_Error_Key ("error.open_action.unsafe_placeholder");
      Add_Error_Key ("error.settings.unknown_section");
      Add_Error_Key ("error.settings.expected_equals");
      Add_Error_Key ("error.settings.invalid_open_action");
      Add_Error_Key ("error.settings.invalid_mapping");
      Add_Error_Key ("error.settings.invalid_view_mode");
      Add_Error_Key ("error.settings.invalid_boolean");
      Add_Error_Key ("error.settings.invalid_theme");
      Add_Error_Key ("error.settings.invalid_icon_theme");
      Add_Error_Key ("error.settings.invalid_sort_field");
      Add_Error_Key ("error.settings.invalid_group");
      Add_Error_Key ("error.settings.invalid_label");
      Add_Error_Key ("error.settings.full");
      Add_Error_Key ("error.compress.links_skipped");
      Add_Error_Key ("error.settings.invalid_column_order");
      Add_Error_Key ("error.settings.invalid_font_pixel_size");
      Add_Error_Key ("error.settings.unknown_key");
      Add_Error_Key ("error.settings.missing_section");
      Add_Error_Key ("error.settings.invalid");
      Add_Error_Key ("error.settings.not_file");
      Add_Error_Key ("error.settings.load");
      Add_Error_Key ("error.settings.save");
      Add_Error_Key ("error.settings.closed");
      Add_Error_Key ("error.window.create");
      for Key of Error_Keys loop
         declare
            Text_Key : constant String := To_String (Key);
         begin
            Assert (Files.Localization.Text (Text_Key) /= Text_Key, "error localization exists for " & Text_Key);
         end;
      end loop;
      --  Why an operation failed is shown in every locale that translates
      --  the generic failure it replaces.
      for Key of Error_Keys loop
         declare
            Text_Key : constant String := To_String (Key);
         begin
            if Text_Key'Length > 9 and then Text_Key (Text_Key'First .. Text_Key'First + 8) = "error.io." then
               for Locale of Western_Locales loop
                  Assert
                    (Files.Localization.Text (Text_Key, To_String (Locale)) /= Files.Localization.Text (Text_Key),
                     To_String (Locale) & " translates " & Text_Key);
               end loop;
            end if;
         end;
      end loop;
      for Id in Files.Commands.Registered_Command_Id loop
         declare
            Name_Key        : constant String := Files.Commands.Name_Key (Id);
            Description_Key : constant String := Files.Commands.Description_Key (Id);
         begin
            Assert (Name_Key /= "", "registered command has a localization name key");
            Assert
              (Files.Localization.Text (Name_Key) /= Name_Key,
               "registered command name is localized for " & Files.Commands.Identifier (Id));
            if Description_Key /= "" then
               Assert
                 (Files.Localization.Text (Description_Key) /= Description_Key,
                  "registered command description is localized for " & Files.Commands.Identifier (Id));
            end if;
         end;
      end loop;
   end Test_Localization_Error_And_Command_Keys;
