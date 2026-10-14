with Ada.Strings.Unbounded;
with Ada.Text_IO;

--  Bounded physical-line input for host pseudo-files and other text protocols.
package Files.Bounded_Text_IO is
   --  Read and consume one physical line. Lines longer than Maximum are
   --  consumed in full but returned as incomplete, so their remaining bytes
   --  can never be interpreted as a second record.
   --  @param File Open text file positioned before a line.
   --  @param Maximum Largest accepted line length.
   --  @param Line Complete line, or empty when the record exceeded Maximum.
   --  @param Complete True only when the whole physical line fit.
   procedure Read_Line
     (File     : in out Ada.Text_IO.File_Type;
      Maximum  : Positive;
      Line     : out Ada.Strings.Unbounded.Unbounded_String;
      Complete : out Boolean);
end Files.Bounded_Text_IO;
