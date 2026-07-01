with Ada.Strings.Unbounded;

package body Files.Breadcrumbs is
   use Ada.Strings.Unbounded;

   function Segments
     (Path : String)
      return Segment_Vectors.Vector
   is
      Result   : Segment_Vectors.Vector;
      Ancestor : Unbounded_String := Null_Unbounded_String;
      Index    : Integer := Path'First;
      Absolute : constant Boolean :=
        Path'Length > 0 and then Path (Path'First) = '/';
   begin
      if Path = "" then
         return Result;
      end if;

      if Absolute then
         Result.Append
           (Segment'
              (Label         => To_Unbounded_String ("/"),
               Ancestor_Path => To_Unbounded_String ("/")));
         Index := Path'First + 1;
      end if;

      while Index <= Path'Last loop
         declare
            Comp_Start : constant Integer := Index;
            Comp_End   : Integer := Index - 1;
         begin
            while Index <= Path'Last and then Path (Index) /= '/' loop
               Comp_End := Index;
               Index := Index + 1;
            end loop;

            --  Skip the separator that ended this component.
            if Index <= Path'Last then
               Index := Index + 1;
            end if;

            if Comp_End >= Comp_Start then
               declare
                  Name : constant String := Path (Comp_Start .. Comp_End);
               begin
                  if Length (Ancestor) = 0 then
                     Ancestor :=
                       (if Absolute
                        then To_Unbounded_String ("/" & Name)
                        else To_Unbounded_String (Name));
                  else
                     Ancestor := Ancestor & "/" & Name;
                  end if;
                  Result.Append
                    (Segment'
                       (Label         => To_Unbounded_String (Name),
                        Ancestor_Path => Ancestor));
               end;
            end if;
         end;
      end loop;

      return Result;
   end Segments;

   function Is_Ellipsis
     (Item : Segment)
      return Boolean is
   begin
      return Length (Item.Ancestor_Path) = 0;
   end Is_Ellipsis;

   function Elide
     (Items        : Segment_Vectors.Vector;
      Max_Segments : Positive)
      return Segment_Vectors.Vector
   is
      Result : Segment_Vectors.Vector;
      Count  : constant Natural := Natural (Items.Length);
   begin
      if Count <= Max_Segments then
         return Items;
      end if;

      if Max_Segments < 3 then
         for I in Count - Max_Segments + 1 .. Count loop
            Result.Append (Items.Element (I));
         end loop;
         return Result;
      end if;

      Result.Append (Items.First_Element);
      Result.Append
        (Segment'
           (Label         => To_Unbounded_String (Ellipsis_Label),
            Ancestor_Path => Null_Unbounded_String));

      declare
         Tail : constant Natural := Max_Segments - 2;
      begin
         for I in Count - Tail + 1 .. Count loop
            Result.Append (Items.Element (I));
         end loop;
      end;

      return Result;
   end Elide;

end Files.Breadcrumbs;
