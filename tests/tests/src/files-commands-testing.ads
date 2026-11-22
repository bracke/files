--  What the suite reaches of Files.Commands that is not part of its interface.
package Files.Commands.Testing is

   --  Parse the key name produced by Key_Text back into a key code, or
   --  Key_Unknown when the text names no key.
   --
   --  @param Text A lowercase key name (e.g. "a", "f5", "backspace").
   --  @return The matching key code, or Key_Unknown.
   function Text_To_Key (Text : String) return Guikit.Input.Key_Code;

   --  Return whether a command may execute while the root selector is open.
   --
   --  @param Id Command identifier.
   --  @return True when the root-selector modal state allows the command.
   function Allowed_With_Root_Selector
     (Id : Command_Id)
      return Boolean;

   --  Return whether a command may execute while the settings pane is open.
   --
   --  @param Id Command identifier.
   --  @return True when the settings-pane modal state allows the command.
   function Allowed_With_Settings_Pane
     (Id : Command_Id)
      return Boolean;

end Files.Commands.Testing;
