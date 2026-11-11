separate (Files.Application.Windows)
procedure Release_Window (Runtime : in out Runtime_Window) is
begin
   --  Stop helpers before settings writes or graphics shutdown can delay
   --  native cleanup. A cleared handle also prevents queued input dispatch.
   Release_Window_Jobs (Runtime.Model, Runtime.Watch);
   --  The background readers' slots for this window go with it.
   Files.Extra_Info_Reader.Release (Files.Extra_Info_Reader.Requester (Runtime.A11y_Key));
   Files.Preview_Decoder.Release (Files.Preview_Decoder.Requester (Runtime.A11y_Key));
   if Runtime.Handle = null then
      return;
   end if;
   --  History ends: originals kept for Undo go to the system trash.
   Files.Operations.Release_History (Runtime.Model);
   Save_Pending_Zoom (Runtime, Force => True);
   if Glfw.Windows.Initialized (As_Window (Runtime.Handle)) then
      declare
         Window_W : Glfw.Size := 0;
         Window_H : Glfw.Size := 0;
      begin
         Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
         if Window_W > 0 and then Window_H > 0
           and then (Runtime.Settings.Window_Width /= Natural (Window_W)
                     or else Runtime.Settings.Window_Height /= Natural (Window_H))
         then
            Files.Controller.Commit_Settings
              (Runtime.Model, Runtime.Settings,
               (Runtime.Settings with delta Window_Width => Natural (Window_W),
                                            Window_Height => Natural (Window_H)),
               To_String (Runtime.Settings_Path));
         end if;
      end;
   end if;
   Guikit.Vulkan.Shutdown (Runtime.Vulkan);
   if Glfw.Windows.Initialized (As_Window (Runtime.Handle)) then
      Glfw.Windows.Drop.Paths.Forget (As_Window (Runtime.Handle));
      Glfw.Windows.Destroy (As_Window (Runtime.Handle));
   end if;
   Free_Window (Runtime.Handle);
   Files.Accessibility.Forget (Runtime.A11y_Key);
end Release_Window;
