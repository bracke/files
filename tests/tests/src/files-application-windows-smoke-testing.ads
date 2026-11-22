--  Test-only access to Files.Application.Windows.Smoke's private part.
package Files.Application.Windows.Smoke.Testing is

   --  One window model rendered as --runtime-smoke renders each startup
   --  window (Smoke.Check_Window_Frame).
   --
   --  @param Model Window model to render.
   --  @param Settings Settings the window is drawn with.
   --  @param Width Framebuffer width used for frame construction.
   --  @param Height Framebuffer height used for frame construction.
   --  @return What the frame came to.
   function Check_Window_Frame
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Width    : Natural;
      Height   : Natural)
      return Window_Frame_Check;

end Files.Application.Windows.Smoke.Testing;
