separate (Files.Controller)
   function Handle_Right_Click
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Target     : Files.Input_Actions.Right_Click_Target;
      Item_Index : Natural;
      X          : Natural;
      Y          : Natural)
      return Controller_Result
   is
      use type Files.Input_Actions.Right_Click_Target;
      --  Any input-owning overlay must swallow the click exactly as left-clicks
      --  are suppressed behind these overlays. Otherwise a right-click in the
      --  grid region behind the modal would open a context menu on top and the
      --  next left-click would execute file commands from a state where they
      --  should be unreachable. An open context menu does not count:
      --  right-clicking elsewhere replaces it with a new menu.
      Overlay_Open : constant Boolean :=
        Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.UI_Types.Context_Menu_Overlay);
      Outcome : Controller_Result := Make_Result (Controller_Ignored);
   begin
      if Target = Files.Input_Actions.On_Context_Menu and then Files.Model.Context_Menu.Is_Open (Model) then
         return Outcome;
      elsif Target = Files.Input_Actions.On_Details_Header and then not Overlay_Open then
         --  A right-click on the details-view column header opens the column
         --  configuration menu regardless of any item under the header band.
         Files.Model.Context_Menu.Open (Model, X, Y, Files.UI_Types.Context_Menu_Header);
      elsif Target = Files.Input_Actions.On_Main_View and then not Overlay_Open then
         if Item_Index > Files.Model.Visible_Count (Model) then
            --  A queued pointer action can outlive the snapshot that produced
            --  its visible index. Do not turn that stale index into an item
            --  menu operating on whatever selection happens to be current.
            Files.Model.Context_Menu.Close (Model);
         elsif Item_Index /= 0 then
            --  Match desktop file-manager convention: right-click on an
            --  unselected item immediately selects it so the user can see what
            --  the menu commands will operate on. A right-click on something
            --  already part of the selection preserves the full multi-selection.
            if not Files.Model.Selection.Is_Selected (Model, Positive (Item_Index)) then
               --  A menu still open for another item would make the
               --  click below ignored, leaving nothing selected.
               Files.Model.Context_Menu.Close (Model);
               Files.Model.Selection.Clear (Model);
               Outcome :=
                 Handle_Item_Click
                   (Model         => Model,
                    Settings      => Settings,
                    Visible_Index => Item_Index,
                    Activate      => False,
                    Modifiers     => Guikit.Input.No_Modifiers);
            end if;
            Files.Model.Context_Menu.Open (Model, X, Y, Files.UI_Types.Context_Menu_Item);
         else
            Files.Model.Context_Menu.Open (Model, X, Y, Files.UI_Types.Context_Menu_Empty);
         end if;
      else
         Files.Model.Context_Menu.Close (Model);
      end if;
      return Outcome;
   end Handle_Right_Click;
