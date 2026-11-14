separate (Files.Application.Windows)
   overriding procedure Key_Changed
     (Object   : not null access Desktop_Window;
      Key      : Glfw.Input.Keys.Key;
      Scancode : Glfw.Input.Keys.Scancode;
      Action   : Glfw.Input.Keys.Action;
      Mods     : Glfw.Input.Keys.Modifiers)
   is
      use type Glfw.Input.Keys.Action;
      use type Guikit.Input.Key_Code;
   begin
      Object.Last_Was_Tracked_Press := False;
      Object.Drop_Next_Character := False;
      if Action = Glfw.Input.Keys.Release then
         return;
      end if;
      declare
         Code : constant Guikit.Input.Key_Code := Glfw.Input.Keys.Codes.To_Key_Code (Layout_Key (Key, Scancode));
      begin
         if Code = Guikit.Input.Key_Unknown then
            return;
         --  A held key repeats as the system's own repeat settings say: the
         --  window system sends Repeat for it.
         elsif Action = Glfw.Input.Keys.Repeat and then not Key_Repeats (Code) then
            Object.Drop_Next_Character := True;
         elsif Natural (Object.Pending_Input.Length) < Max_Pending_Input_Events then
            Object.Pending_Input.Append
              (Input_Event'
                 (Kind      => Key_Press_Event,
                  Key       => Code,
                  Modifiers => Glfw.Input.Keys.Codes.To_Modifiers (Mods),
                  others    => <>));
            Object.Last_Was_Tracked_Press := True;
         end if;
      end;
   exception
      when Swallowed : others =>
         --  GLFW calls this from C: an exception must not unwind into it.
         --  The event is lost, the window is not.
         Files.Diagnostics.Note_Event_Loop (Swallowed);
   end Key_Changed;
