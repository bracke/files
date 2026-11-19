separate (Files.Rendering.Build_Frame_Commands)
   function Toggles_Topmost_Overlay (Command : Files.Commands.Command_Id) return Boolean is
      Position : constant Natural := Topmost_Overlay_Position (Snapshot);
   begin
      if Position = 0 then
         return False;
      end if;
      --  As Files.Events routes a click on it: the root selector's own click
      --  handling takes its toolbar button, and a click outside the sort
      --  menu (its bottom-bar button included) closes it.
      case Files.UI_Types.Overlay_Stack (Position) is
         when Files.UI_Types.Root_Selector_Overlay =>
            return Command = Files.Commands.Select_Drive_Command;
         when Files.UI_Types.Sort_Menu_Overlay =>
            return Command = Files.Commands.Toggle_Sort_Menu_Command;
         when others =>
            return False;
      end case;
   end Toggles_Topmost_Overlay;
