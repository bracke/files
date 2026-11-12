separate (Files.Events.Translate_Click)
--  The folder-tree panel: its close button, rows, scrollbar and pick bar.
procedure Tree_Panel_Click (Handled : out Boolean; Result : out Input_Action) is
   Tree_Panel_L : constant Files.Rendering.Tree_Panel_Layout :=
     Files.Rendering.Calculate_Tree_Panel_Layout (Snapshot, Layout, Line_Height);

   --  A press on the tree scrollbar: on the thumb it begins a drag, on the
   --  track it pages by one panel of rows towards the press. The bar shows
   --  only while more rows than fit (and at least one fits), so a page is
   --  never empty.
   function Tree_Scroll_Click return Input_Action is
     (Scroll_Click
        (Target       => Scroll_Tree_Panel,
         Thumb_Y      => Tree_Panel_L.Scrollbar_Thumb_Y,
         Thumb_Height => Tree_Panel_L.Scrollbar_Height,
         Step         => Files.Rendering.Tree_Row_Capacity (Snapshot, Tree_Panel_L),
         Raw          => Snapshot.Tree_Panel_Scroll_Rows,
         Maximum      => Files.Rendering.Tree_Max_Scroll (Snapshot, Tree_Panel_L)));
begin
   Handled := True;
   if Snapshot.Tree_Panel_Open then
      if Close_Button_Hit
           (Tree_Panel_L.X, Tree_Panel_L.Y,
            Tree_Panel_L.Width, Tree_Panel_L.Height)
      then
         Result := Command_Action (Files.Commands.Toggle_Folder_Tree_Command);
         return;
      end if;

      if Tree_Panel_L.Scrollbar_Visible
        and then Within
          (X, Tree_Panel_L.Scrollbar_X, Tree_Panel_L.Scrollbar_Width)
        and then Within
          (Y, Tree_Panel_L.Scrollbar_Y, Tree_Panel_L.Scrollbar_Track_Height)
      then
         Result := Tree_Scroll_Click;
         return;
      end if;

      --  While the destination picker is active its Choose/Cancel button bar
      --  sits over the bottom of the tree and is hit-tested before the rows.
      if Snapshot.Tree_Pick_Active then
         declare
            Buttons : constant Files.Rendering.Tree_Pick_Button_Layout :=
              Files.Rendering.Tree_Pick_Buttons (Tree_Panel_L, Line_Height);
         begin
            if Buttons.Visible then
               if Within (X, Buttons.Choose_X, Buttons.Button_Width)
                 and then Within (Y, Buttons.Y, Buttons.Height)
               then
                  Result := Tree_Pick_Confirm_Action;
                  return;
               elsif Within (X, Buttons.Cancel_X, Buttons.Button_Width)
                 and then Within (Y, Buttons.Y, Buttons.Height)
               then
                  Result := Command_Action (Files.Commands.Toggle_Folder_Tree_Command);
                  return;
               end if;
            end if;
         end;
      end if;
      declare
         Tree_Rows_L         : constant Files.Rendering.Tree_Row_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Tree_Row_Layout (Snapshot, Tree_Panel_L, Line_Height);
         Tree_Triangle_Index : constant Natural := Files.Rendering.Hit.Tree_Triangle_At (Tree_Rows_L, X, Y);
         Tree_Node_Index     : constant Natural := Files.Rendering.Hit.Tree_Row_At (Tree_Rows_L, X, Y);
      begin
         if Tree_Triangle_Index /= 0 then
            Result := Tree_Action (Tree_Triangle_Index, Toggle => True);
            return;
         elsif Tree_Node_Index /= 0 then
            Result := Tree_Action (Tree_Node_Index, Toggle => False);
            return;
         end if;
      end;
      if Within (X, Tree_Panel_L.X, Tree_Panel_L.Width)
        and then Within (Y, Tree_Panel_L.Y, Tree_Panel_L.Height)
      then
         --  Consume clicks on the tree panel chrome so they do not fall
         --  through to items drawn behind the sidebar.
         Result := No_Action;
         return;
      end if;

      --  Destination picking is modal: only the tree and its Choose/Cancel
      --  controls are active until the operation is confirmed or cancelled.
      if Snapshot.Tree_Pick_Active then
         Result := No_Action;
         return;
      end if;
   end if;
   Handled := False;
   Result := No_Action;
end Tree_Panel_Click;
