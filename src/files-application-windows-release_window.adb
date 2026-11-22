with Files.Operations.History;
separate (Files.Application.Windows)
procedure Release_Window (Runtime : in out Runtime_Window) is
begin
   --  Stop helpers before settings writes or graphics shutdown can delay
   --  native cleanup. A cleared handle also prevents queued input dispatch.
   Release_Window_Jobs (Runtime.Model, Runtime.Watch);
   --  The background readers' slots for this window go with it.
   Files.Application.Extra_Info_Reader.Release (Files.Application.Extra_Info_Reader.Requester (Runtime.A11y_Key));
   Files.Application.Preview_Decoder.Release (Files.Application.Preview_Decoder.Requester (Runtime.A11y_Key));
   Files.Application.Tree_Reader.Release (Files.Application.Tree_Reader.Requester (Runtime.A11y_Key));
   if Runtime.Handle = null then
      return;
   end if;
   --  History ends: originals kept for Undo go to the system trash.
   Files.Operations.History.Release_History (Runtime.Model);
   Save_Pending_Zoom (Runtime, Force => True);
   Save_Held_Settings (Runtime, Force => True);
   if Glfw.Windows.Initialized (As_Window (Runtime.Handle)) then
      declare
         Window_W : Glfw.Size := 0;
         Window_H : Glfw.Size := 0;
      begin
         Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
         --  A window closing has no error line left to read a failure on.
         if Window_W > 0 and then Window_H > 0 then
            Files.Controller.Remember_Window_Size
              (Runtime.Model, Runtime.Settings, To_String (Runtime.Settings_Path),
               Width => Positive (Window_W), Height => Positive (Window_H));
         end if;
      end;
   end if;
   Guikit.Vulkan.Shutdown (Runtime.Vulkan);
   if Glfw.Windows.Initialized (As_Window (Runtime.Handle)) then
      Glfw.Windows.Drop.Paths.Forget (As_Window (Runtime.Handle));
      Glfw.Windows.Destroy (As_Window (Runtime.Handle));
   end if;
   Free_Window (Runtime.Handle);
   Files.Application.Accessibility.Forget (Runtime.A11y_Key);
end Release_Window;
