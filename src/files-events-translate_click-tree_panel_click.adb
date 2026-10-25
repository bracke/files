separate (Files.Events.Translate_Click)
--  The folder-tree panel: its close button, rows, scrollbar and pick bar.
procedure Tree_Panel_Click (Handled : out Boolean; Result : out Input_Action) is
begin
   Handled := True;
   if Snapshot.Tree_Panel_Open then
      if Close_Button_Hit
           (Tree_Panel_L.X, Tree_Panel_L.Y,
            Tree_Panel_L.Width, Tree_Panel_L.Height)
      then
         Result := Command_Action (Files.Commands.Toggle_Folder_Tree_Command, Activate);
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
                  Result := Tree_Pick_Confirm_Action (Activate);
                  return;
               elsif Within (X, Buttons.Cancel_X, Buttons.Button_Width)
                 and then Within (Y, Buttons.Y, Buttons.Height)
               then
                  Result := Command_Action (Files.Commands.Toggle_Folder_Tree_Command, Activate);
                  return;
               end if;
            end if;
         end;
      end if;
      if Tree_Triangle_Index /= 0 then
         Result := Tree_Action (Tree_Triangle_Index, Toggle => True);
         return;
      elsif Tree_Node_Index /= 0 then
         Result := Tree_Action (Tree_Node_Index, Toggle => False);
         return;
      elsif Within (X, Tree_Panel_L.X, Tree_Panel_L.Width)
        and then Within (Y, Tree_Panel_L.Y, Tree_Panel_L.Height)
      then
         --  Consume clicks on the tree panel chrome so they do not fall
         --  through to items drawn behind the sidebar.
         Result := No_Action (Activate);
         return;
      end if;

      --  Destination picking is modal: only the tree and its Choose/Cancel
      --  controls are active until the operation is confirmed or cancelled.
      if Snapshot.Tree_Pick_Active then
         Result := No_Action (Activate);
         return;
      end if;
   end if;
   Handled := False;
   Result := No_Action (Activate);
end Tree_Panel_Click;
