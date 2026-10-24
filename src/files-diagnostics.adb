with Ada.Environment_Variables;
with Ada.Text_IO;

package body Files.Diagnostics is

   procedure Note
     (Occurrence : Ada.Exceptions.Exception_Occurrence;
      Where      : String) is
   begin
      if Ada.Environment_Variables.Exists ("FILES_DIAGNOSTICS") then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            --  A developer trace, not prose: a fixed marker for grep.
            "files-diagnostics" & ':' & ' ' & Where & ':' & ' '
            & Ada.Exceptions.Exception_Information (Occurrence));
      end if;
   exception
      --  A trace must never turn a tolerated failure into a new one.
      when others =>
         null;
   end Note;

end Files.Diagnostics;
