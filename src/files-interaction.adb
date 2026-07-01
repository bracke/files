with Ada.Strings.Unbounded;

with Files.Command_Palette;
with Files.Operations;

package body Files.Interaction is

   use Ada.Strings.Unbounded;
   use type Files.Commands.Command_Id;
   use type Files.Controller.Controller_Status;

   --  Map the model's runtime sort enum onto the settings enum.
   function Settings_Sort_Of
     (Field : Files.Model.Sort_Field) return Files.Settings.Sort_Field is
   begin
      case Field is
         when Files.Model.Sort_Name     => return Files.Settings.Sort_By_Name;
         when Files.Model.Sort_Type     => return Files.Settings.Sort_By_Filetype;
         when Files.Model.Sort_Size     => return Files.Settings.Sort_By_Size;
         when Files.Model.Sort_Created  => return Files.Settings.Sort_By_Created;
         when Files.Model.Sort_Changed  => return Files.Settings.Sort_By_Modified;
      end case;
   end Settings_Sort_Of;

   procedure Persist_Settings
     (Settings      : Files.Settings.Settings_Model;
      Settings_Path : String)
   is
      Saved : Files.Settings.Settings_Write_Result;
   begin
      if Settings_Path = "" then
         return;
      end if;
      Saved := Files.Settings.Save_Text (Settings_Path, Files.Settings.To_Text (Settings));
      pragma Unreferenced (Saved);
   end Persist_Settings;

   --  Copy the user-visible global UI state from the model into the settings
   --  record and persist it. Called whenever a runtime command flips one of the
   --  persisted toggles. Returns True when a change was written.
   function Sync_Global_UI_State
     (Model         : Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Boolean
   is
      use type Files.Types.View_Mode;
      use type Files.Settings.Sort_Field;

      New_View  : constant Files.Types.View_Mode :=
        Files.Model.View_Mode_Of (Model);
      New_Sort  : constant Files.Settings.Sort_Field :=
        Settings_Sort_Of (Files.Model.Sort_Field_Of (Model));
      New_Asc   : constant Boolean :=
        Files.Model.Sort_Is_Ascending (Model);
      New_Info  : constant Boolean :=
        Files.Model.Info_Pane_Is_Open (Model);
      Changed   : constant Boolean :=
        Settings.Default_View /= New_View
        or else Settings.Sort_Field_Value /= New_Sort
        or else Settings.Sort_Ascending /= New_Asc
        or else Settings.Info_Pane_Open /= New_Info;
   begin
      if not Changed then
         return False;
      end if;

      Settings.Default_View := New_View;
      Settings.Sort_Field_Value := New_Sort;
      Settings.Sort_Ascending := New_Asc;
      Settings.Info_Pane_Open := New_Info;
      Persist_Settings (Settings, Settings_Path);
      return True;
   end Sync_Global_UI_State;

   procedure Execute_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Current_Font_Size : Positive;
      Modifiers         : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Result            : out Interaction_Result)
   is
      Outcome : Files.Controller.Controller_Result;
   begin
      Result.Command := Command;

      if not Files.Commands.Is_Enabled (Command, Model) then
         Outcome := Files.Controller.Execute_Command (Command, Model, Settings, Modifiers);
         Result.Status := Outcome.Status;
         Result.Command_Executed := Outcome.Status = Files.Controller.Controller_Command_Executed;
         return;
      end if;

      case Command is
         when Files.Commands.Save_Settings_Command =>
            Outcome :=
              Files.Controller.Save_Settings (Model, Settings, Settings_Path);
            Result.Settings_Changed := True;
            --  Apply a font-size change made in the settings pane live, the same
            --  way Ctrl+scroll / Ctrl+= zoom does: signal the shell to sync the
            --  runtime size and invalidate the glyph cache so text re-rasterizes
            --  now rather than only on the next launch.
            if Settings.Font_Pixel_Size /= Current_Font_Size then
               Result.Font_Size_Changed := True;
               Result.Needs_Glyph_Rebuild := True;
            end if;
         when Files.Commands.Toggle_Hidden_Files_Command =>
            Outcome :=
              Files.Controller.Toggle_Hidden_Files (Model, Settings, Settings_Path);
            Result.Settings_Changed := True;
            Result.Directory_Reloaded := True;
         when Files.Commands.Toggle_Bookmark_Command =>
            declare
               Current   : constant String := Files.Model.Current_Path (Model);
               Existing  : Boolean := False;
               To_Remove : Natural := 0;
            begin
               if Current /= "" then
                  for Index in
                    Settings.Bookmark_Paths.First_Index ..
                    Settings.Bookmark_Paths.Last_Index
                  loop
                     if To_String (Settings.Bookmark_Paths.Element (Index)) = Current then
                        Existing := True;
                        To_Remove := Index;
                        exit;
                     end if;
                  end loop;
                  if Existing then
                     Settings.Bookmark_Paths.Delete (To_Remove);
                  else
                     Settings.Bookmark_Paths.Append (To_Unbounded_String (Current));
                  end if;
                  Persist_Settings (Settings, Settings_Path);
                  Result.Settings_Changed := True;
               end if;
               Outcome :=
                 (Status => Files.Controller.Controller_Command_Executed, others => <>);
            end;
         when Files.Commands.Toggle_Column_Modified_Command
            | Files.Commands.Toggle_Column_Size_Command
            | Files.Commands.Toggle_Column_Type_Command
            | Files.Commands.Toggle_Column_Created_Command
            | Files.Commands.Toggle_Column_Permissions_Command =>
            declare
               Column : constant Files.Types.Detail_Column :=
                 (case Command is
                     when Files.Commands.Toggle_Column_Modified_Command =>
                        Files.Types.Modified_Column,
                     when Files.Commands.Toggle_Column_Size_Command =>
                        Files.Types.Size_Column,
                     when Files.Commands.Toggle_Column_Type_Command =>
                        Files.Types.Filetype_Column,
                     when Files.Commands.Toggle_Column_Created_Command =>
                        Files.Types.Created_Column,
                     when others =>
                        Files.Types.Permissions_Column);
            begin
               Settings := Files.Settings.Toggle_Column (Settings, Column);
               Persist_Settings (Settings, Settings_Path);
               Result.Settings_Changed := True;
               Outcome :=
                 (Status => Files.Controller.Controller_Command_Executed, others => <>);
            end;
         when Files.Commands.Cycle_Group_By_Command =>
            Settings := Files.Settings.Cycle_Group_By (Settings);
            Persist_Settings (Settings, Settings_Path);
            Result.Settings_Changed := True;
            Outcome :=
              (Status => Files.Controller.Controller_Command_Executed, others => <>);
         when others =>
            Outcome := Files.Controller.Execute_Command (Command, Model, Settings, Modifiers);
      end case;

      case Command is
         when Files.Commands.Select_Small_Icons_Command
            | Files.Commands.Select_Large_Icons_Command
            | Files.Commands.Select_Details_Command
            | Files.Commands.Sort_By_Name_Command
            | Files.Commands.Sort_By_Size_Command
            | Files.Commands.Sort_By_Type_Command
            | Files.Commands.Sort_By_Created_Command
            | Files.Commands.Sort_By_Changed_Command
            | Files.Commands.Toggle_Info_Pane_Command =>
            if Sync_Global_UI_State (Model, Settings, Settings_Path) then
               Result.Settings_Changed := True;
            end if;
         when others =>
            null;
      end case;

      --  A sort change reorders the listing. The renderer re-sorts the snapshot
      --  for display, but the model's item order (used by keyboard navigation)
      --  is the load order, so re-list the directory to keep them in sync.
      --  Sync above has already updated the settings sort field that Refresh uses.
      case Command is
         when Files.Commands.Sort_By_Name_Command
            | Files.Commands.Sort_By_Size_Command
            | Files.Commands.Sort_By_Type_Command
            | Files.Commands.Sort_By_Created_Command
            | Files.Commands.Sort_By_Changed_Command =>
            declare
               Reloaded : constant Files.Operations.Operation_Result :=
                 Files.Operations.Refresh (Model, Settings);
               pragma Unreferenced (Reloaded);
            begin
               null;
            end;
            Result.Directory_Reloaded := True;
         when others =>
            null;
      end case;

      Result.Status := Outcome.Status;
      Result.Command_Executed := Outcome.Status = Files.Controller.Controller_Command_Executed;
   end Execute_Command;

   procedure Handle_Key
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Key               : Files.Types.Key_Code;
      Modifiers         : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Current_Font_Size : Positive;
      Result            : out Interaction_Result)
   is
      Outcome : constant Files.Controller.Controller_Result :=
        Files.Controller.Handle_Key
          (Model     => Model,
           Settings  => Settings,
           Key       => Key,
           Modifiers => Modifiers);
   begin
      if Outcome.Command = Files.Commands.Save_Settings_Command
        or else Outcome.Command = Files.Commands.Toggle_Hidden_Files_Command
      then
         --  Re-route settings-path commands through Execute_Command for the
         --  in-out settings handling, exactly as the shell did inline. The
         --  shell then dropped any parallel character event; surface that as a
         --  follow-up flag so Apply_Interaction_Result performs the clear.
         Execute_Command
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => Settings_Path,
            Command           => Outcome.Command,
            Current_Font_Size => Current_Font_Size,
            Result            => Result);
         Result.Clear_Pending_Text := True;
      else
         Result.Command := Outcome.Command;
         Result.Status := Outcome.Status;
         Result.Command_Executed :=
           Outcome.Status = Files.Controller.Controller_Command_Executed;
      end if;
   end Handle_Key;

   procedure Apply_Input_Action
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Action            : Files.Events.Input_Action;
      Current_Font_Size : Positive;
      Modifiers         : Files.Types.Modifier_Set;
      Result            : out Interaction_Result)
   is
      Outcome : Files.Controller.Controller_Result;
   begin
      case Action.Kind is
         when Files.Events.Command_Input_Action =>
            if Files.Commands.Requires_Settings_Path (Action.Command) then
               Execute_Command
                 (Model, Settings, Settings_Path, Action.Command,
                  Current_Font_Size, Modifiers, Result);
            else
               Outcome :=
                 Files.Controller.Handle_Command_Click
                   (Action.Command, Model, Settings, Modifiers);
               Result.Command := Action.Command;
               Result.Status := Outcome.Status;
               Result.Command_Executed :=
                 Outcome.Status = Files.Controller.Controller_Command_Executed;
            end if;
         when Files.Events.Item_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Item_Click
                (Model         => Model,
                 Settings      => Settings,
                 Visible_Index => Action.Item_Index,
                 Activate      => Action.Activate,
                 Modifiers     => Modifiers);
            Result.Status := Outcome.Status;
         when Files.Events.Root_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Root_Click
                (Model, Settings, Action.Root_Index);
            Result.Status := Outcome.Status;
         when Files.Events.Command_Result_Click_Input_Action =>
            declare
               Results : constant Files.Command_Palette.Result_Vectors.Vector :=
                 Files.Command_Palette.Search
                   (Files.Model.Command_Palette_Query (Model), Model);
            begin
               if Action.Result_Index > 0
                 and then Action.Result_Index <= Natural (Results.Length)
                 and then Files.Commands.Requires_Settings_Path
                   (Results.Element (Positive (Action.Result_Index)).Command)
               then
                  Files.Model.Set_Command_Palette_Selected_Index (Model, Action.Result_Index);
                  if Results.Element (Positive (Action.Result_Index)).Enabled then
                     Execute_Command
                       (Model, Settings, Settings_Path,
                        Results.Element (Positive (Action.Result_Index)).Command,
                        Current_Font_Size, Modifiers, Result);
                     if Result.Status /= Files.Controller.Controller_Ignored then
                        Files.Model.Close_Command_Palette (Model);
                     end if;
                  else
                     Outcome :=
                       Files.Controller.Handle_Command_Result_Click
                         (Model        => Model,
                          Settings     => Settings,
                          Result_Index => Action.Result_Index,
                          Modifiers    => Modifiers);
                     Result.Status := Outcome.Status;
                  end if;
               else
                  Outcome :=
                    Files.Controller.Handle_Command_Result_Click
                      (Model        => Model,
                       Settings     => Settings,
                       Result_Index => Action.Result_Index,
                       Modifiers    => Modifiers);
                  Result.Status := Outcome.Status;
               end if;
            end;
         when Files.Events.Text_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Text_Click
                (Model           => Model,
                 Target          => Action.Focus_Target,
                 Cursor_Position => Action.Cursor_Position,
                 Item_Index      => Action.Item_Index);
            Result.Status := Outcome.Status;
         when Files.Events.Settings_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Settings_Click
                (Model  => Model,
                 Field  => Action.Settings_Field,
                 Option => Action.Settings_Option);
            Result.Status := Outcome.Status;
            if Outcome.Command = Files.Commands.Save_Settings_Command
              or else Outcome.Command = Files.Commands.Toggle_Hidden_Files_Command
            then
               Execute_Command
                 (Model, Settings, Settings_Path, Outcome.Command,
                  Current_Font_Size, Files.Types.No_Modifiers, Result);
               Result.Clear_Pending_Text := True;
            end if;
         when Files.Events.Scroll_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Targeted_Scroll
                (Model, Action.Scroll_Area, Action.Scroll_Lines);
            Result.Status := Outcome.Status;
         when Files.Events.Scrollbar_Drag_Begin_Input_Action
            | Files.Events.No_Input_Action
            | Files.Events.Selection_Input_Action =>
            --  Scrollbar-drag begin updates runtime drag state owned by the
            --  shell; the no-op kinds are ignored. Nothing to apply here.
            null;
      end case;
   end Apply_Input_Action;

   procedure Apply_Context_Menu_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Current_Font_Size : Positive;
      Modifiers         : Files.Types.Modifier_Set;
      Result            : out Interaction_Result) is
   begin
      Files.Model.Close_Context_Menu (Model);
      if Command /= Files.Commands.No_Command then
         Execute_Command
           (Model, Settings, Settings_Path, Command,
            Current_Font_Size, Modifiers, Result);
      end if;
      Result.Context_Menu_Changed := True;
   end Apply_Context_Menu_Command;

   procedure Apply_Right_Click
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      In_Main    : Boolean;
      Item_Index : Natural;
      X          : Natural;
      Y          : Natural;
      Result     : out Interaction_Result)
   is
      --  A modal overlay (settings, palette, root selector, sort menu) must
      --  swallow the click exactly as left-clicks are suppressed behind these
      --  overlays. Otherwise a right-click in the grid region behind the modal
      --  would open a context menu on top and the next left-click would execute
      --  file commands from a state where they should be unreachable.
      Overlay_Open : constant Boolean :=
        Files.Model.Settings_Pane_Is_Open (Model)
        or else Files.Model.Command_Palette_Is_Open (Model)
        or else Files.Model.Root_Selector_Is_Open (Model)
        or else Files.Model.Sort_Menu_Is_Open (Model);
   begin
      if In_Main and then not Overlay_Open then
         if Item_Index /= 0 then
            --  Match desktop file-manager convention: right-click on an
            --  unselected item immediately selects it so the user can see what
            --  the menu commands will operate on. A right-click on something
            --  already part of the selection preserves the full multi-selection.
            if Item_Index <= Files.Model.Visible_Count (Model)
              and then not Files.Model.Is_Selected (Model, Positive (Item_Index))
            then
               declare
                  Click_Result : Files.Controller.Controller_Result;
               begin
                  Files.Model.Clear_Selection (Model);
                  Click_Result :=
                    Files.Controller.Handle_Item_Click
                      (Model         => Model,
                       Settings      => Settings,
                       Visible_Index => Item_Index,
                       Activate      => False,
                       Modifiers     => Files.Types.No_Modifiers);
                  Result.Status := Click_Result.Status;
               end;
            end if;
            Files.Model.Open_Context_Menu
              (Model, X, Y, Files.Model.Context_Menu_Item, Item_Index);
         else
            Files.Model.Open_Context_Menu (Model, X, Y, Files.Model.Context_Menu_Empty);
         end if;
      else
         Files.Model.Close_Context_Menu (Model);
      end if;
      Result.Context_Menu_Changed := True;
   end Apply_Right_Click;

end Files.Interaction;
