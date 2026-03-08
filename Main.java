public class Main {
    public static void main(String[] args) {
        int N = 7;
        int K = 3;
        int arr[] = {1,2,3,4,5,6,7};

        for(int i=K; i < N+K; i++){
            System.out.print(arr[i%N] + " ");
        }
    }
}