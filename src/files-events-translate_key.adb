separate (Files.Events)
   function Translate_Key
     (Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set)
      return Input_Action
   is
      Command : constant Files.Commands.Command_Id := Files.Commands.Find_By_Shortcut (Key, Modifiers);
   begin
      if Command /= Files.Commands.No_Command then
         return Command_Action (Command);
      end if;

      if Modifiers = Guikit.Input.No_Modifiers
        or else
          (Modifiers (Guikit.Input.Shift_Key)
           and then not Modifiers (Guikit.Input.Control_Key)
           and then not Modifiers (Guikit.Input.Alt_Key)
           and then not Modifiers (Guikit.Input.Meta_Key))
      then
         case Key is
            when Guikit.Input.Key_Left =>
               return
                 (Kind            => Selection_Input_Action,
                  Direction       => Guikit.Input.Move_Left,
                  Range_Selection => Modifiers (Guikit.Input.Shift_Key),
                  others          => <>);
            when Guikit.Input.Key_Right =>
               return
                 (Kind            => Selection_Input_Action,
                  Direction       => Guikit.Input.Move_Right,
                  Range_Selection => Modifiers (Guikit.Input.Shift_Key),
                  others          => <>);
            when Guikit.Input.Key_Up =>
               return
                 (Kind            => Selection_Input_Action,
                  Direction       => Guikit.Input.Move_Up,
                  Range_Selection => Modifiers (Guikit.Input.Shift_Key),
                  others          => <>);
            when Guikit.Input.Key_Down =>
               return
                 (Kind            => Selection_Input_Action,
                  Direction       => Guikit.Input.Move_Down,
                  Range_Selection => Modifiers (Guikit.Input.Shift_Key),
                  others          => <>);
            when others =>
               null;
         end case;
      end if;

      return No_Action;
   end Translate_Key;
