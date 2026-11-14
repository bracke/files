separate (Files.Application.Windows)
   overriding procedure Character_Entered
     (Object : not null access Desktop_Window;
      Char   : Wide_Wide_Character)
   is
      Bytes    : constant String := Text_Input_Bytes (Char);
      Parallel : constant Boolean := Object.Last_Was_Tracked_Press;
      Dropped  : constant Boolean := Object.Drop_Next_Character;
   begin
      Object.Last_Was_Tracked_Press := False;
      Object.Drop_Next_Character := False;
      if Bytes = "" or else Dropped then
         return;
      end if;
      --  Plain typing coalesces into one event; a key's own character stays
      --  separate so a consumed shortcut can drop exactly that character.
      if not Parallel
        and then not Object.Pending_Input.Is_Empty
        and then Object.Pending_Input.Last_Element.Kind = Text_Event
        and then not Object.Pending_Input.Last_Element.Parallel
      then
         declare
            Last : Input_Event renames Object.Pending_Input (Object.Pending_Input.Last_Index);
         begin
            Append (Last.Text, Bytes);
         end;
      elsif Natural (Object.Pending_Input.Length) < Max_Pending_Input_Events then
         Object.Pending_Input.Append
           (Input_Event'(Kind => Text_Event, Text => To_Unbounded_String (Bytes), Parallel => Parallel, others => <>));
      end if;
   exception
      when Swallowed : others =>
         --  GLFW calls this from C: an exception must not unwind into it.
         --  The event is lost, the window is not.
         Files.Diagnostics.Note_Event_Loop (Swallowed);
   end Character_Entered;
