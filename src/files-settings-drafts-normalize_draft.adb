separate (Files.Settings.Drafts)
   procedure Normalize_Draft
     (Draft : in out Settings_Draft)
   is
      --  Truncate Values to at most Count entries.
      --
      --  @param Values List to truncate in place.
      --  @param Count Maximum number of entries to keep.
      procedure Trim_To_Count
        (Values : in out Files.Types.String_Vectors.Vector;
         Count  : Natural) is
      begin
         while Natural (Values.Length) > Count loop
            Values.Delete (Natural (Values.Length));
         end loop;
      end Trim_To_Count;

      --  Pair one mapping's parallel lists and clamp its selection.
      --
      --  @param Keys Key list.
      --  @param Values Value list.
      --  @param Index Selected row (one-based, 0 when empty).
      --  @param Selected_Key The selected row's key.
      --  @param Selected_Value The selected row's value.
      procedure Normalize_Pair
        (Keys           : in out Files.Types.String_Vectors.Vector;
         Values         : in out Files.Types.String_Vectors.Vector;
         Index          : in out Natural;
         Selected_Key   : out Unbounded_String;
         Selected_Value : out Unbounded_String)
      is
         Count : constant Natural := Natural'Min (Natural (Keys.Length), Natural (Values.Length));
      begin
         Trim_To_Count (Keys, Count);
         Trim_To_Count (Values, Count);
         if Count = 0 then
            Index := 0;
            Selected_Key := Null_Unbounded_String;
            Selected_Value := Null_Unbounded_String;
         else
            if Index = 0 or else Index > Count then
               Index := 1;
            end if;
            Selected_Key := Keys.Element (Index);
            Selected_Value := Values.Element (Index);
         end if;
      end Normalize_Pair;
   begin
      Normalize_Pair
        (Draft.Filetype_Keys,
         Draft.Filetype_Values,
         Draft.Filetype_Index,
         Draft.Filetype_Extension,
         Draft.Filetype_Value);
      Normalize_Pair
        (Draft.Icon_Keys,
         Draft.Icon_Values,
         Draft.Icon_Index,
         Draft.Icon_Filetype,
         Draft.Icon_Value);
      Normalize_Pair
        (Draft.Open_Action_Keys,
         Draft.Open_Action_Commands,
         Draft.Open_Action_Index,
         Draft.Open_Action_Token,
         Draft.Open_Action_Command);
   end Normalize_Draft;
