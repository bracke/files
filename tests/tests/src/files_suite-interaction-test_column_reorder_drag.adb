separate (Files_Suite.Interaction)
   procedure Test_Column_Reorder_Drag (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Detail_Column;
      use type Files.Types.Detail_Column_Order;
      use type Files.Types.Sort_Field;

      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
   begin
      for Index in 1 .. 8 loop
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "item-" & Index_Image (Index),
               Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize
        (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root,
         Default_View_Mode => Files.Types.Details);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Rows     : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
         Row      : Files.Rendering.Item_Layout;
         Found    : Boolean := False;
         Header_Y : Natural;
         Cell_X   : Natural;
         Drop_X   : Natural;
         Action   : Files.Events.Input_Action;
         Drop     : Natural;
      begin
         for Cell of Rows loop
            if Cell.Visible_Index = 1 then
               Row := Cell;
               Found := True;
               exit;
            end if;
         end loop;
         Assert (Found, "the details list lays out a first data row");
         Header_Y := (Layout.Main_Y + Row.Y) / 2;
         Cell_X   := Row.Size_X + Row.Size_Width / 2;
         Drop_X   := Row.Modified_X + Row.Modified_Width / 2;

         --  A press on the size column's cell body (clear of any separator)
         --  begins a reorder drag carrying the dragged column and its sort
         --  command, rather than immediately sorting.
         Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, Cell_X, Header_Y, Window_W, Window_H, Line_Height => Line);
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.Column_Reorder_Begin_Input_Action,
            "a press on a header cell body begins a column reorder");
         Files_Suite.Support.Assert_Equal
           (Files.Types.Detail_Column'Val (Action.Item_Index),
            Files.Types.Size_Column,
            "the reorder targets the column whose cell body was pressed");
         Files_Suite.Support.Assert_Equal
           (Action.Command,
            Files.Commands.Sort_By_Size_Command,
            "the reorder-begin action carries the column's sort command for the click fallback");

         --  Dropping the dragged column over the modified column moves it there
         --  and persists the new order.
         Drop :=
           Files.Rendering.Details_Header_Drop_Index
             (Snapshot, Layout, Drop_X, Header_Y, Line_Height => Line);
         Assert (Drop in Files.Types.Detail_Column_Index,
                 "the drop coordinate resolves to a valid target slot");
         Files.Interaction.Apply_Column_Reorder
           (Model, Settings, "", Files.Types.Size_Column, Drop, Result);
         Assert (Result.Settings_Changed, "the reorder drop reports a persisted change");
         Files_Suite.Support.Assert_Equal
           (Settings.Column_Order (2),
            Files.Types.Size_Column,
            "the dropped column takes the target slot in the persisted order");
      end;

      --  A press/release with no movement still sorts: applying the sort command
      --  the reorder-begin action carried changes the sort field and leaves the
      --  column order untouched.
      declare
         Fresh    : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Order_Before : constant Files.Types.Detail_Column_Order := Fresh.Column_Order;
         Sort_Before  : constant Files.Types.Sort_Field := Files.Model.Sort_Field_Of (Model);
         Sort_Action  : constant Files.Events.Input_Action :=
           (Kind    => Files.Events.Command_Input_Action,
            Command => Files.Commands.Sort_By_Size_Command,
            others  => <>);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Fresh, "", Sort_Action, Base_Font, Guikit.Input.No_Modifiers, Result);
         Assert (Files.Model.Sort_Field_Of (Model) /= Sort_Before,
                 "a click without a drag applies the sort command");
         Assert (Fresh.Column_Order = Order_Before,
                 "a sort click leaves the column order unchanged");
      end;

      --  A press on a header separator still begins a resize, never a reorder.
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Rows     : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
         Row      : Files.Rendering.Item_Layout;
         Found    : Boolean := False;
         Action   : Files.Events.Input_Action;
      begin
         for Cell of Rows loop
            if Cell.Visible_Index = 1 then
               Row := Cell;
               Found := True;
               exit;
            end if;
         end loop;
         Assert (Found, "the reordered details list lays out a first data row");
         Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, Row.Size_X, (Layout.Main_Y + Row.Y) / 2,
              Window_W, Window_H, Line_Height => Line);
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.Column_Resize_Begin_Input_Action,
            "a separator press still begins a resize, not a reorder");
      end;
   end Test_Column_Reorder_Drag;
