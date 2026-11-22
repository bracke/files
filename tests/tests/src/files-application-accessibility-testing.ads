--  Test-only views of the application's accessibility tree.
package Files.Application.Accessibility.Testing is

   --  How many windows the application's tree holds now.
   --
   --  @return The number of windows published and not forgotten since Stop.
   function Published_Windows return Natural;

   --  Map the frame's flat accessibility nodes into a hierarchical A11ykit tree
   --  -- the toolkit-neutral form a screen-reader provider consumes -- inferring
   --  the parent/child structure from the nodes' geometry.
   --
   --  @param Frame Render frame containing accessibility nodes.
   --  @return The nodes as an A11ykit.Tree with inferred hierarchy and focus.
   function To_A11ykit_Tree
     (Frame : Files.Rendering.Frame_Commands)
      return A11ykit.Tree.Accessibility_Tree;

end Files.Application.Accessibility.Testing;
