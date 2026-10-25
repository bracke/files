separate (Files_Suite.Commands)
   procedure Test_Range_Edges_And_Picker_Tree (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Shift    : constant Guikit.Input.Modifier_Set :=
        [Guikit.Input.Shift_Key => True, others => False];
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Result   : Files.Controller.Controller_Result;
      pragma Unreferenced (Result);

      function U8 (Text : Wide_Wide_String) return String is
        (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Text));
   begin
      --  Matching folds every script's case, not just Latin-1, and a name
      --  that is not UTF-8 still matches by its bytes.
      Assert
        (Files.Types.Contains_Case_Insensitive (U8 ("ПРИВЕТ мир"), U8 ("привет")),
         "Cyrillic, Polish and Greek names match case-insensitively (Cyrillic)");
      Assert
        (Files.Types.Contains_Case_Insensitive (U8 ("ŁÓDŹ.txt"), U8 ("łódź")),
         "Cyrillic, Polish and Greek names match case-insensitively (Polish)");
      Assert
        (Files.Types.Contains_Case_Insensitive (U8 ("ΕΛΛΆΔΑ"), U8 ("ελλάδα")),
         "Cyrillic, Polish and Greek names match case-insensitively (Greek)");
      Assert (Files.Types.Contains_Case_Insensitive ("BAD" & Character'Val (16#FF#) & ".txt", "bad"),
              "a name that is not UTF-8 still matches");
      if I18N.Normalization.Available then
         Assert (Files.Types.Contains_Case_Insensitive
                   ("cafe" & Character'Val (16#CC#) & Character'Val (16#81#) & ".txt", U8 ("café")),
                 "a decomposed name matches the composed letters typed");
      end if;

      --  Shift+Up on the first item would wrap to the last and select all.
      Files.Model.Set_View_Mode (Model, Files.Types.Details);
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Up, Shift);
      Assert (Files.Model.Selected_Count (Model) = 1 and then Files.Model.Selected_Index (Model) = 1,
              "Shift+Up on the first item selects nothing more");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down, Shift);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down, Shift);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down, Shift);
      Assert (Files.Model.Selected_Count (Model) = Files.Model.Visible_Count (Model)
              and then Files.Model.Selected_Index (Model) = Files.Model.Visible_Count (Model),
              "Shift+Down grows the range to the last item and stops there");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 1, "a plain arrow still wraps");

      --  Copy To on an already open folder tree leaves it open when the pick
      --  ends; a tree the pick opened closes again.
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Folder_Tree_Command, Model, Settings);
      Assert (Files.Model.Tree_Panel_Is_Open (Model), "the folder tree is open");
      Result := Files.Controller.Execute_Command (Files.Commands.Copy_To_Command, Model, Settings);
      Assert (Files.Model.Tree_Pick_Is_Active (Model), "Copy To starts picking a destination");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Tree_Pick_Is_Active (Model) and then Files.Model.Tree_Panel_Is_Open (Model),
              "Escape ends the pick and keeps the tree the user had open");
      Result := Files.Controller.Execute_Command (Files.Commands.Copy_To_Command, Model, Settings);
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Folder_Tree_Command, Model, Settings);
      Assert (not Files.Model.Tree_Pick_Is_Active (Model) and then Files.Model.Tree_Panel_Is_Open (Model),
              "the picker's Cancel keeps it too");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Folder_Tree_Command, Model, Settings);
      Result := Files.Controller.Execute_Command (Files.Commands.Copy_To_Command, Model, Settings);
      Assert (Files.Model.Tree_Panel_Is_Open (Model), "Copy To opens a closed tree to pick in");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Tree_Panel_Is_Open (Model), "and closes it again when the pick ends");
   end Test_Range_Edges_And_Picker_Tree;
