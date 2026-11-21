with Files.Text_Encoding;
separate (Files.File_System.Content_Info)
function Text_Encoding_Name (Path : String) return String is
   --  Classify by sampling a bounded prefix, the way file(1) does. Scanning
   --  the whole file would turn a passive directory browse into an
   --  unbounded read: this runs per regular text file via Extra_Info_Token,
   --  so a multi-GB all-valid-text file (a big log or SQL dump) would
   --  otherwise be read end to end just to render its metadata line.
   Encoding_Sample_Limit : constant := 131_072;

   Success, Complete : Boolean;
   Sample : constant String := Read_Preview_Text (Path, Encoding_Sample_Limit, Success, Complete);
begin
   if not Success then
      return Files.Text_Encoding.Token (Files.Text_Encoding.Binary);
   end if;
   return Files.Text_Encoding.Token (Files.Text_Encoding.Classify (Sample, Complete));
end Text_Encoding_Name;
