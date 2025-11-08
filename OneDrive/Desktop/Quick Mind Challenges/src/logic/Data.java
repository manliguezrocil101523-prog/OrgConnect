package logic;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Contributor:
 *
 * @see
 * <a href="https://harkovindustry.github.io/JPano-Portfolio/">Portfolio</a>
 * @see <a href="https://www.facebook.com/toneiu">Facebook (Main)</a>
 * @see <a href="https://www.facebook.com/studentJPano">Facebook (Student)</a>
 *
 * @since Oct 31, 2025 8:15:21 PM
 * @author tonieu
 */
public final class Data {

    public enum Difficulty {
        EASY,
        MEDIUM,
        HARD;
        
        @Override
        public String toString() {
            return switch(this) {
                case EASY -> "EASY";
                case MEDIUM -> "MEDIUM";
                default -> "HARD";
            };
        }
    }

    public enum Category {
        ENGLISH,
        MATH,
        SCIENCE,
        FILIPINO;
        
        @Override
        public String toString() {
            return switch(this) {
                case ENGLISH -> "ENGLISH";
                case MATH -> "MATH";
                case SCIENCE -> "SCIENCE";
                default -> "FILIPINO";
            };
        }
        
        
    }

    public static boolean fromGamePage = false;

    private static Category category = null;
    private static Difficulty difficulty = null;
    private static int round = 1;
    private static int index = 0;
    private static Map<String, Integer> score = new HashMap<>() {{
        put("correct", 0);
        put("wrong", 0);
    }};

    // ----------------------
    // Static accessors
    // ----------------------
    public static void updateRound() {
        round++;
    }
    
    public static int getRound() {
        return round;
    }

    public static void setCurrentRound(int round) {
        Data.round = round;
    }
    
    public static void resetRound() {
        round = 1;
    }

    public static Category getCategory() {
        return category;
    }

    public static void setCategory(Category category) {
        Data.category = category;
    }

    public static Difficulty getDifficulty() {
        return difficulty;
    }

    public static void setDifficulty(Difficulty difficulty) {
        Data.difficulty = difficulty;
    }

    public static int getIndex() {
        return index;
    }

    public static void setIndex(int index) {
        Data.index = index;
    }

    public static Map<String, Integer> getScore() {
        return score;
    }

    public static void setScore(Map<String, Integer> score) {
        Data.score = score;
    }

    public static void resetScore() {
        score.put("correct", 0);
        score.put("wrong", 0);
    }

    // ----------------------
    // Instance-based round tracking
    // ----------------------
    public static class Round {
        public int roundNumber;
        public int correct;
        public int wrong;
        public int timeTaken; // in seconds
        public String category;
        public Difficulty difficulty;
        public String quiz;

        public Round(int roundNumber, int correct, int wrong, int timeTaken, String category, Difficulty difficulty, String quiz) {
            this.roundNumber = roundNumber;
            this.correct = correct;
            this.wrong = wrong;
            this.timeTaken = timeTaken;
            this.category = category;
            this.difficulty = difficulty;
            this.quiz = quiz;
        }
    }

    private final List<Round> rounds;

    public Data() {
        this.rounds = new ArrayList<>();
    }

    public void addRound(int roundNumber, int correct, int wrong, int timeTaken, String category, Difficulty difficulty, String quiz) {
        rounds.add(new Round(roundNumber, correct, wrong, timeTaken, category, difficulty, quiz));
    }

    public List<Round> getAllRounds() {
        return new ArrayList<>(rounds); // return copy to avoid modification
    }

    public void reset() {
        rounds.clear();
    }
}
