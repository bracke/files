separate (Files.Operations)
   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean is
   begin
      if Query = "" or else Bytes'Length = 0 then
         return False;
      end if;

      --  Skip binary payloads: a decisive NUL or a heavy share of control bytes
      --  means the file is not text, so it can never be a content match.
      if Files.Quick_Look.Looks_Binary (Bytes) then
         return False;
      end if;

      return Ada.Strings.Fixed.Index
        (Files.Types.To_Lower (Bytes), Files.Types.To_Lower (Query)) > 0;
   end Content_Matches;
