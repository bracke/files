separate (Files.Application.Windows.Smoke.Drive_Settings_Keys)
   procedure Press
     (Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set := None;
      Typed     : String := "") is
   begin
      Runtime.Handle.Pending_Input.Append
        (Input_Event'
           (Kind      => Key_Press_Event,
            Key       => Key,
            Modifiers => Modifiers,
            Text      => Null_Unbounded_String,
            Parallel  => False));
      if Typed /= "" then
         Runtime.Handle.Pending_Input.Append
           (Input_Event'
              (Kind      => Text_Event,
               Key       => Key,
               Modifiers => Modifiers,
               Text      => To_Unbounded_String (Typed),
               Parallel  => True));
      end if;
      Handle_Keyboard (Runtime);
      Render_Window (Runtime);
   end Press;
