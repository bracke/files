with Ada.Strings.Unbounded;
with Hostkit.Host;

package body Files.Controller.Clipboard_Text is

   use Ada.Strings.Unbounded;

   function Line_Break return String is
     (if Hostkit.Host."=" (Hostkit.Host.Current, Hostkit.Host.Windows) then ASCII.CR & ASCII.LF
      else [1 => ASCII.LF]);

   function Joined_Full_Paths
     (Items : Files.Items.Item_Vectors.Vector)
      return String
   is
      Result : Unbounded_String;
      First  : Boolean := True;

      --  Path as one line among several: quoted when it would not read as one.
      function Field (Path : String) return String is
         Quoted : Unbounded_String;
      begin
         if not (for some C of Path => C = ASCII.LF or else C = ASCII.CR)
           and then (Path = "" or else Path (Path'First) /= '"')
         then
            return Path;
         end if;
         Append (Quoted, '"');
         for C of Path loop
            if C = '"' then
               Append (Quoted, '"');
            end if;
            Append (Quoted, C);
         end loop;
         Append (Quoted, '"');
         return To_String (Quoted);
      end Field;
   begin
      if Natural (Items.Length) = 1 then
         return To_String (Items.First_Element.Full_Path);
      end if;
      for Item of Items loop
         if not First then
            Append (Result, Line_Break);
         end if;
         Append (Result, Field (To_String (Item.Full_Path)));
         First := False;
      end loop;

      return To_String (Result);
   end Joined_Full_Paths;

end Files.Controller.Clipboard_Text;
