--  The clipboard state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Clipboard is

   --  Record a clipboard snapshot of source paths and a copy/cut mode.
   --
   --  @param Model Model to update.
   --  @param Paths Filesystem paths to remember.
   --  @param Mode  Copy or cut intent for the next paste.
   procedure Set_Clipboard
     (Model : in out Window_Model;
      Paths : Files.Types.String_Vectors.Vector;
      Mode  : Clipboard_Mode);

   --  Clear any pending clipboard snapshot.
   --
   --  @param Model Model to update.
   procedure Clear_Clipboard
     (Model : in out Window_Model);

   --  Return the remembered clipboard source paths.
   --
   --  @param Model Model to inspect.
   --  @return Filesystem paths captured on the last copy or cut.
   function Clipboard_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Return whether the clipboard intent is copy or cut.
   --
   --  @param Model Model to inspect.
   --  @return Clipboard_None when no clipboard snapshot exists.
   function Clipboard_Mode_Of
     (Model : Window_Model)
      return Clipboard_Mode;

   --  Return whether the clipboard has at least one remembered path.
   --
   --  @param Model Model to inspect.
   --  @return True when paste can act.
   function Clipboard_Has_Items
     (Model : Window_Model)
      return Boolean;

   --  Record text to be written to the system text clipboard by the platform
   --  shell on its next follow-up pass. The model only stores the request; the
   --  GLFW-backed shell performs the actual clipboard write and clears it.
   --
   --  @param Model Model to update.
   --  @param Text Text to place on the system clipboard.
   procedure Set_System_Clipboard_Request
     (Model : in out Window_Model;
      Text  : String);

   --  Return whether a system-clipboard write has been requested and not yet
   --  consumed by the shell.
   --
   --  @param Model Model to inspect.
   --  @return True when a pending system-clipboard request exists.
   function System_Clipboard_Request_Pending
     (Model : Window_Model)
      return Boolean;

   --  Return the text of the pending system-clipboard request.
   --
   --  @param Model Model to inspect.
   --  @return Requested clipboard text, or an empty string when none is pending.
   function System_Clipboard_Request_Text
     (Model : Window_Model)
      return String;

   --  Clear any pending system-clipboard request once the shell has written it.
   --
   --  @param Model Model to update.
   procedure Clear_System_Clipboard_Request
     (Model : in out Window_Model);

end Files.Model.Clipboard;
