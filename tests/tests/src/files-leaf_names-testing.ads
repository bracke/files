--  What the suite reaches of Files.Leaf_Names that is not part of its interface.
package Files.Leaf_Names.Testing is

   --  Head cut down at a whole UTF-8 character, as little as needed, with
   --  Tail kept whole after it, so the result measures at most Room.
   --
   --  @param Head The part that may be shortened (a stem).
   --  @param Tail The part kept whole (a counter and an extension).
   --  @param Room The most the result may measure (Length_Under).
   --  @param Unit How the result is measured.
   --  @return Head's longest prefix that fits, then Tail; just Tail when no
   --    prefix fits, which then may still not.
   function Cut
     (Head : String;
      Tail : String;
      Room : Natural;
      Unit : Hostkit.Fs.Name_Length_Unit := Hostkit.Fs.Bytes)
      return String;

end Files.Leaf_Names.Testing;
