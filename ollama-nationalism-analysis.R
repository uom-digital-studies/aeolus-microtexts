nationalism_type <- ellmer::type_object(
  "Analyse a text for nationalist ideas",
  label = ellmer::type_enum(
    "Nationalist orientation of the sentence",
    values = c("nationalist", "ambivalent", "anti-nationalist")
  ),
  score = ellmer::type_number(
    "Nationalism index, from -1 (strongly anti-nationalist) to 1 (strongly nationalist)"
  )
)
