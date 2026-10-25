with System;
with A11ykit.Provider;

with Files.Rendering;

with A11ykit.Tree;

--  Accessibility bridge for exporting render accessibility nodes.
package Files.Accessibility is

   --  Map the frame's flat accessibility nodes into a hierarchical A11ykit tree
   --  -- the toolkit-neutral form a screen-reader provider consumes -- inferring
   --  the parent/child structure from the nodes' geometry.
   --
   --  @param Frame Render frame containing accessibility nodes.
   --  @return The nodes as an A11ykit.Tree with inferred hierarchy and focus.
   function To_A11ykit_Tree
     (Frame : Files.Rendering.Frame_Commands)
      return A11ykit.Tree.Accessibility_Tree;

   --  Begin and end the application's host screen-reader lifetime. Native
   --  providers defer registration until Publish supplies the first root tree.
   --
   --  Both are idempotent and no-ops on an unsupported host.
   procedure Start;
   procedure Stop;

   --  Identifies one files window to the screen reader; 0 is no window.
   type Window_Key is new Natural;

   --  Answer the screen reader for Window through its native handle (an
   --  HWND, an NSWindow), the window the host's screen reader looks at. A
   --  no-op where the host needs no window.
   --
   --  @param Window The files window.
   --  @param Native Its native handle.
   procedure Attach_Window (Window : Window_Key; Native : System.Address);

   --  A key no other window has had.
   --
   --  @return The new key.
   function New_Window_Key return Window_Key;

   --  Publish a window's frame as that window's part of the application's
   --  accessibility tree, which holds every open window. On Linux, Windows,
   --  and macOS the a11y provider attempts native registration and
   --  publication; when the host service is unavailable it still validates
   --  the semantic tree through the toolkit's fallback backend.
   --
   --  @param Window The window the frame was drawn for.
   --  @param Frame Render frame containing accessibility nodes.
   procedure Publish (Window : Window_Key; Frame : Files.Rendering.Frame_Commands);

   --  Take a closed window out of the tree.
   --
   --  @param Window The window that closed.
   procedure Forget (Window : Window_Key);

   --  Answer the screen reader's pending queries from the last published
   --  tree. Called on every pass of the event loop: a screen reader asks
   --  whenever it likes, not only when a frame changes.
   procedure Service;

   --  Report which files window has the keyboard focus (0 for none); only a
   --  change reaches the screen reader, as a window (de)activation.
   --
   --  @param Window The focused window, or 0.
   procedure Set_Active (Window : Window_Key);

   --  The oldest thing the screen reader asked files to do, if any: activate
   --  or focus a node of a window's last frame, given by its rectangle in
   --  that window.
   --
   --  @param Window The window the request is for.
   --  @param Item The request.
   --  @return False when none is waiting.
   function Next_Request
     (Window : out Window_Key;
      Item   : out A11ykit.Provider.Request)
      return Boolean;

end Files.Accessibility;
