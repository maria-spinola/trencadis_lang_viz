import processing.data.JSONObject;

  void jsonToMusic(String jsonString) {
    JSONObject data = JSONObject.parse(jsonString);

    int emotion        = data.getInt("emotion");
    int word_class     = data.getInt("word_class");
    int abstraction    = data.getInt("abstraction");
    int agency         = data.getInt("agency");
    int organic        = data.getInt("organic");
    int phenomena_class = data.getInt("phenomena_class");
    int time_duration  = data.getInt("time_duration");

    playWord(emotion, word_class, abstraction, agency, organic, phenomena_class, time_duration);
  }