import pandas as pd



def get_ref_icons():

    icons = {}

    with open("icons.dart", "r") as f:

        for line in f.readlines():

            if "_rounded = IconData(" in line:

                name = line.split(" ")[3]

                code = line.split("IconData(")[1].split(",")[0]

                if code.startswith("0x"):

                    icons[name] = code

    return icons



def main():

    icons = get_ref_icons()



    df = pd.read_json("../assets/icons/category_icons.json")

    df = df.apply(lambda x: icons[x["icon_name"]], axis=1)



if __name__ == "__main__":

    main()

