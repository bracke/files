separate (Files.File_System)
function Valid_Leaf_Name
  (Name  : String;
   Rules : Name_Rules := Host_Rules)
   return Boolean
is
   Windows_Rules_Apply : constant Boolean :=
     (case Rules is
         when Windows_Rules => True,
         when Posix_Rules   => False,
         when Host_Rules    => Hostkit.Host.Current = Hostkit.Host.Windows);

   Index     : Integer := Name'First;
   Codepoint : Natural := 0;
begin
   --  Broken or purely confusing on every host: the special entries, the
   --  POSIX path separator (checked per character below), malformed UTF-8,
   --  and names that are only or trail in whitespace (invisible, ambiguous).
   if Name = ""
     or else Name = "."
     or else Name = ".."
     or else not Files.UTF8.Is_Valid (Name)
     or else Is_All_Whitespace (Name)
     or else Ends_With_Whitespace (Name)
   then
      return False;
   end if;

   --  Windows strips or forbids these, so a name carrying them cannot
   --  round-trip there; a POSIX host accepts them as ordinary filenames.
   if Windows_Rules_Apply
     and then (Name (Name'Last) = '.'
               or else Is_Windows_Device_Name (Name))
   then
      return False;
   end if;

   while Index <= Name'Last loop
      Files.UTF8.Decode_Next_Codepoint (Name, Index, Codepoint);

      if Codepoint < 32
        or else Codepoint = 127
        or else Codepoint in 16#80# .. 16#9F#
      then
         return False;
      elsif Codepoint < 128 then
         declare
            Character_Value : constant Character := Character'Val (Codepoint);
         begin
            if Character_Value = '/' then
               return False;
            elsif Windows_Rules_Apply
              and then (Character_Value = '\'
                        or else Character_Value = '<'
                        or else Character_Value = '>'
                        or else Character_Value = ':'
                        or else Character_Value = Character'Val (34)
                        or else Character_Value = '|'
                        or else Character_Value = '?'
                        or else Character_Value = '*')
            then
               return False;
            end if;
         end;
      end if;
   end loop;

   return True;
end Valid_Leaf_Name;
