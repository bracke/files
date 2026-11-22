with Files.Items;

--  The text Copy Path puts on the system clipboard: the selected items'
--  full paths, one per line. Pure; the window layer writes the clipboard
--  from the request Files.Model.Clipboard records.
package Files.Controller.Clipboard_Text is

   --  Join the full paths of the given items into one text, one path per
   --  line, in item order: lines end CR LF on Windows, LF elsewhere (Line_Break).
   --  One path is copied exactly as it is. Among several, a path that holds a
   --  line break or starts with '"' -- which pasted would read as two paths,
   --  or as a quoted one -- is written in double quotes, a '"' inside it
   --  doubled, as a spreadsheet reads a field. Returns an empty string when no
   --  items are supplied. This is the pure, filesystem-free text seam the
   --  Copy_Path_Command uses before the platform layer writes the system
   --  clipboard.
   --
   --  @param Items Items whose full paths are joined.
   --  @return The joined full paths, or an empty string when Items is empty.
   function Joined_Full_Paths
     (Items : Files.Items.Item_Vectors.Vector)
      return String;

   --  The line break between copied paths: CR LF on Windows, LF elsewhere.
   --
   --  @return The line break.
   function Line_Break return String;

end Files.Controller.Clipboard_Text;
