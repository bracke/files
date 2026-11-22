--  What the suite reaches of Files.Controller.Clipboard_Text that is not part of its interface.
package Files.Controller.Clipboard_Text.Testing is

   --  The line break between copied paths: CR LF on Windows, LF elsewhere.
   --
   --  @return The line break.
   function Line_Break return String;

end Files.Controller.Clipboard_Text.Testing;
