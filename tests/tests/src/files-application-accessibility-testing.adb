package body Files.Application.Accessibility.Testing is

   function Published_Windows return Natural renames Files.Application.Accessibility.Published_Windows;

   function Waiting_Windows return Natural renames Files.Application.Accessibility.Waiting_Windows;

   function To_A11ykit_Tree
     (Frame : Files.Rendering.Frame_Commands)
      return A11ykit.Tree.Accessibility_Tree renames Files.Application.Accessibility.To_A11ykit_Tree;

   procedure Ignore_Listeners (Ignore : Boolean) renames Files.Application.Accessibility.Ignore_Listeners;

end Files.Application.Accessibility.Testing;
