separate (Files.File_System)
function Content_Matches
  (Bytes : String;
   Query : String)
   return Boolean
is
   --  UTF-16 and Windows-1252 text searched as the UTF-8 it says.
   Text : constant String := Files.Types.Searchable_Text (Bytes);
begin
   if Query = "" or else Text'Length = 0 then
      return False;
   end if;

   --  Skip binary payloads: a decisive NUL or a heavy share of control bytes
   --  means the file is not text, so it can never be a content match.
   if Files.Types.Looks_Binary (Text) then
      return False;
   end if;

   return Ada.Strings.Fixed.Index
     (Files.Types.Fold_Case (Text), Files.Types.Fold_Case (Query)) > 0;
end Content_Matches;
