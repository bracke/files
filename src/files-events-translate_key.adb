separate (Files.Events)
   function Translate_Key
     (Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set)
      return Input_Action
   is
      Command    : constant Files.Commands.Command_Id := Files.Commands.Find_By_Shortcut (Key, Modifiers);
      Navigation : constant Grid_Navigation := Grid_Navigation_Of (Key);
   begin
      if Command /= Files.Commands.No_Command then
         return Command_Action (Command);
      end if;

      --  An arrow, plain or with Shift (which extends the selection), is a
      --  selection step; the other grid keys are the controller's
      --  (Files.Controller.Handle_Key), which knows what owns them.
      if Navigation.Move = Grid_Step
        and then
          (Modifiers = Guikit.Input.No_Modifiers
           or else
             (Modifiers (Guikit.Input.Shift_Key)
              and then not Modifiers (Guikit.Input.Control_Key)
              and then not Modifiers (Guikit.Input.Alt_Key)
              and then not Modifiers (Guikit.Input.Meta_Key)))
      then
         return
           (Kind      => Selection_Input_Action,
            Direction => Navigation.Direction,
            Extend    => Modifiers (Guikit.Input.Shift_Key));
      end if;

      return No_Action;
   end Translate_Key;
